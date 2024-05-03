public class rveSeatingArrangementUpdated {
    
    public class IASeatingArrangementDetails{
        @AuraEnabled
        public list<contact> ContactList {get;set;}
        @AuraEnabled
        public set<string> EligibleStudents {get;set;}
        @AuraEnabled
        public set<string> InEligibleStudents {get;set;}
        @AuraEnabled
        public Integer SizeOfStudents{get;set;}
    }
    
    public class FacilityWithAllotments{
        @AuraEnabled
        public String RoomNo {get;set;}
        @AuraEnabled
        public String Block {get;set;}
        @AuraEnabled
        public String Floor {get;set;}
        @AuraEnabled
        public Integer Capacity {get;set;}
        @AuraEnabled
        public Id FacilityId {get;set;}
        @AuraEnabled
        public Integer RemainingCapacity {get;set;}
    }
    
    @AuraEnabled(cacheable=true)
    public static list<hed__Program_Plan__c> getActivePrograms(){
        
        List<Rve_Exam_Notification__c>ActiveExamNotifications = [Select Id,hed_Program_Batch__c from Rve_Exam_Notification__c where rve_Active__c = true and Rve_Publish__c= true];
        
        Set<Id>ActivePrograms = new set<Id>();
        
        if(!ActiveExamNotifications.isEmpty())
        {
            for(Rve_Exam_Notification__c ProgramInstance: ActiveExamNotifications)
            {
                ActivePrograms.add(ProgramInstance.hed_Program_Batch__c);
            }
        }
        
        System.debug('ProgramBatches=> '+ActivePrograms);
        List<hed__Program_Plan__c> ProgramPlans = [select Id,name,hed__Account__c
                                                   from hed__Program_Plan__c where Id In:ActivePrograms
                                                   and( hed__Account__r.School_Head__c=:UserInfo.getUserId() OR hed__Account__r.Vertical_Head__c=:UserInfo.getUserId())];
        System.debug('ProgramList=> '+ProgramPlans);
        System.debug('ProgramVatchSize=> '+ProgramPlans.size());
        return ProgramPlans;
    }

    @AuraEnabled
    public static string updateFacilities(Map<String,Integer> FacilityWithUpdatedCapacity,String ProgramBatchId){
        System.debug('FacilityWithUpdatedCapacity=> '+FacilityWithUpdatedCapacity.size());

        String status = '';
        try {
            list<hed__Facility__c>UpdatedFacility = new list<hed__Facility__c>();
            String AccountId = getAccountId(ProgramBatchId);
            list<hed__Facility__c>ExistingFacility = [SELECT Id, name, hed__Capacity__c, Facility_Booked__c, Room_Name__c, Room__c, Floor__c, Block__c
            FROM hed__Facility__c 
            WHERE hed__Account__c = :AccountId];

            System.debug('ExistingFacility=> '+ExistingFacility.size());

            System.debug('FacilityWithUpdatedCapacity=> '+FacilityWithUpdatedCapacity.keyset());
            if(!ExistingFacility.isEmpty())
            {
                for(hed__Facility__c ht: ExistingFacility)
                {
                    if(FacilityWithUpdatedCapacity.containskey(ht.Id))
                    {
                        ht.hed__Capacity__c = FacilityWithUpdatedCapacity.get(ht.Id);
                        UpdatedFacility.add(ht);
                    }
                }
            }
            if(UpdatedFacility.size() >0 )
            {
                System.debug('UpdatedFacility=> '+UpdatedFacility);
                update UpdatedFacility;
                status = 'successful';
            }
            
        } catch (Exception e) {
System.debug('Line=> '+e.getLineNumber()+' Exception=> '+e.getMessage());
          status = e.getMessage();
        }
        return status;
    }
    
    public static Time parseTime(String timeString) {
        Time formattedTime;
        try {
            // Split the string to extract hours, minutes, and seconds
            List<String> parts = timeString.split(':');
            Integer hours = Integer.valueOf(parts[0]);
            Integer minutes = Integer.valueOf(parts[1]);
            Integer seconds = Integer.valueOf(parts[2].substring(0, 2)); // Remove ' AM' or ' PM'
            
            // Adjust hours if it's PM
            if (timeString.endsWith(' PM') && hours != 12) {
                hours += 12;
            } else if (timeString.endsWith(' AM') && hours == 12) {
                hours = 0;
            }
            
            // Construct a Time instance
            formattedTime = Time.newInstance(hours, minutes, seconds, 0);
        } catch (Exception e) {
            formattedTime = null;
            System.debug('Error parsing time: ' + e.getMessage());
        }
        return formattedTime;
    }


    
    @AuraEnabled
    public static List<FacilityWithAllotments> getRelatedSchool(String ProgramBatchId,String IAType,String Session,Date DateOfExam,String ExamTime){
        System.debug('ExamTime'+ExamTime);
        // Construct a Time instance
        Time timeValue = parseTime(ExamTime);
        System.debug('Time value: ' + timeValue);
        try {
            hed__Program_Plan__c Ht = [Select Id,hed__Account__c from hed__Program_Plan__c where Id=:ProgramBatchId];
            list<FacilityWithAllotments>AllFacilities = getFacilitiesDetails(Ht.hed__Account__c,IAType,Session,DateOfExam,timeValue);
            System.debug('AllFacilities=> '+AllFacilities);
            return AllFacilities;
        } catch (Exception e) {
            System.debug('Exception=> '+e.getMessage());
            return new List<FacilityWithAllotments>();
        }
    }
    
    @AuraEnabled
    public static List<FacilityWithAllotments> getFacilitiesDetails(String AccountId,String IAType,String Session,Date DateOfExam,Time ExamTime){
        List<FacilityWithAllotments> FacilityList = new List<FacilityWithAllotments>();
        
        // Query existing allotments for the given account
        List<IA_Seating_Room_Allotment__c> existingAllotments = [SELECT Id, Name, Facility_Type__c, Facility_Type__r.Block__c, Facility_Type__r.Floor__c, Remaining_Capacity__c,Capacity__c 
                                                                 FROM IA_Seating_Room_Allotment__c 
                                                                 WHERE School__c = :AccountId and IA_Type__c=:IAType and rveShift__c=:Session and rve_Date_of_Exam__c=:DateOfExam
                                                                 and Exam_Time__c=:ExamTime];
        
        System.debug('ExistingAllotments=> '+existingAllotments);
        // Populate FacilityList with existing allotments
        if(!existingAllotments.isEmpty())
        {
            for(IA_Seating_Room_Allotment__c allotment : existingAllotments) {
                if(allotment.Remaining_Capacity__c!=0 && allotment.Remaining_Capacity__c>0)
                {
                    FacilityWithAllotments allotDetails = new FacilityWithAllotments();
                    allotDetails.RoomNo = allotment.Name;
                    allotDetails.Block = allotment.Facility_Type__r.Block__c;
                    allotDetails.Floor = allotment.Facility_Type__r.Floor__c;
                    allotDetails.Capacity = Integer.valueOf(allotment.Capacity__c);
                    allotDetails.RemainingCapacity = Integer.valueOf(allotment.Remaining_Capacity__c);
                    allotDetails.FacilityId = allotment.Facility_Type__c;
                    FacilityList.add(allotDetails);
                }
            }
        }
        // Create a set of existing allotment IDs
        Set<Id> existingFacilityIds = new Set<Id>();
        
        if(!existingAllotments.isEmpty())
        {
            for(IA_Seating_Room_Allotment__c Allotment : existingAllotments) {
                existingFacilityIds.add(Allotment.Facility_Type__c);
            }
        }
        System.debug('existingFacilities =>'+ existingFacilityIds);
        System.debug('AccountId=> '+AccountId);
        // Query related facilities not already included in existing allotments
        List<hed__Facility__c> relatedFacilities = [SELECT Id, name, hed__Capacity__c, Facility_Booked__c, Room_Name__c, Room__c, Floor__c, Block__c
                                                    FROM hed__Facility__c 
                                                    WHERE hed__Account__c = :AccountId AND Id NOT IN :existingFacilityIds];
        
        System.debug('RelatedFacilities=> '+relatedFacilities);
        
        // Populate FacilityList with related facilities
        if(!relatedFacilities.isEmpty())
        {
            for(hed__Facility__c facility : relatedFacilities) {
                FacilityWithAllotments allotDetails = new FacilityWithAllotments();
                allotDetails.RoomNo = facility.Room__c;
                allotDetails.Block = facility.Block__c;
                allotDetails.Floor = facility.Floor__c;
                allotDetails.Capacity = Integer.valueOf(facility.hed__Capacity__c);
                allotDetails.RemainingCapacity = Integer.valueOf(facility.hed__Capacity__c);
                allotDetails.FacilityId = facility.Id;
                FacilityList.add(allotDetails);
            }
        }
        System.debug('AllotmentSize => ' + FacilityList);
        System.debug('AllotmentSize => ' + FacilityList.size());  
        return FacilityList;
    }
    
    
    @AuraEnabled
    public static List<hed_Time_Table_Line_Item__c> getRevaExamNotifications(String IAType,String Session,Id ProgramId){
        try {
            System.debug('AccountId=> '+ProgramId);
            List<hed_Time_Table_Line_Item__c>TimeTableItems = new List<hed_Time_Table_Line_Item__c>();
            
            if(Session== 'Morning')
            {
                System.debug('Morning');
                TimeTableItems = 
                    [Select Id,name,Reva_Exam_Notification__r.hed_program_Batch__c,hed_Date__c,hed_Start_Time__c from hed_Time_Table_Line_Item__c
                     where Reva_Exam_Notification__r.rve_Active__c=true AND Reva_Exam_Notification__r.Rve_Publish__c=true
                     AND Reva_Exam_Notification__r.hed_IA_Type__c =: IAType AND Reva_Exam_Notification__r.hed_Program_Batch__c=:ProgramId
                     AND HOUR_IN_DAY(hed_Start_Time__c) >= 8 
                     AND HOUR_IN_DAY(hed_Start_Time__c) < 12 Order By hed_Date__c];
            }
            else{
                TimeTableItems = 
                    [Select Id,name,Reva_Exam_Notification__r.hed_program_Batch__c,hed_Date__c,hed_Start_Time__c from hed_Time_Table_Line_Item__c
                     where Reva_Exam_Notification__r.rve_Active__c=true and Reva_Exam_Notification__r.Rve_Publish__c=true
                     and Reva_Exam_Notification__r.hed_IA_Type__c =: IAType AND Reva_Exam_Notification__r.hed_Program_Batch__c=:ProgramId
                     AND HOUR_IN_DAY(hed_Start_Time__c) > 12 Order By hed_Date__c];
            }
            
            if(!TimeTableItems.isEmpty())
            {
                return TimeTableItems;
            }
            else{
                return new List<hed_Time_Table_Line_Item__c>();
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string checkProgramBatchAllotment(String ActiveProgramBatch,Date dateOfExam, String shift, String examTime){
        try {
           String status = '';

           Time FormattedTime = parseTime(ExamTime);

           List<IA_Seating_Room_Allotment__c> existingAllotments = [SELECT Id, Name, Remaining_Capacity__c,Alloted_Students__c,InEligible_SRN__c,Total_Students__c,Facility_Type__c,Capacity__c,Assigned_Program_Batches__c
           FROM IA_Seating_Room_Allotment__c
           WHERE rve_Date_of_Exam__c = :dateOfExam AND rveShift__c = :shift AND Exam_Time__c=:formattedTime and Assigned_Program_Batches__c LIKE :('%' + ActiveProgramBatch + '%')];
        
           if(!existingAllotments.isEmpty())
           status = 'found';

           return status;
        } catch (Exception e) {
            System.debug('Line=> '+e.getLineNumber()+' Exception=> '+e.getMessage());
            return e.getMessage();
        }
    }
    
    @AuraEnabled
    public static String createOrUpdateAllotment(String ActiveProgramBatch,List<Object> UpdateExistingCapacity, List<hed__Facility__c> facilityList,List<string> EligibleStudents,List<string> InEligibleStudents, Date dateOfExam, String shift, String examTime) {
        System.debug('ActiveProgramBatch=> '+ActiveProgramBatch);
        System.debug('UpdateExistingCapacity=> '+UpdateExistingCapacity);

        Time timeValue = parseTime(ExamTime);

        hed_Time_Table_Line_Item__c TimeTable = [Select Id,name,hed_End_Time__c,Course__r.Name,Reva_Exam_Notification__r.Name,Reva_Exam_Notification__r.hed_program_Batch__c,hed_Date__c,hed_Start_Time__c from hed_Time_Table_Line_Item__c
                     where Reva_Exam_Notification__r.rve_Active__c=true AND Reva_Exam_Notification__r.Rve_Publish__c=true
                     AND hed_Start_Time__c=:timeValue AND hed_Date__c=:dateOfExam Limit 1];

        Time EndTime = TimeTable.hed_End_Time__c;
        System.debug('250=> '+EndTime);

        Map<String, Integer> facilityMap = new Map<String, Integer>();
    for (Object obj : UpdateExistingCapacity) {
        List<Object> entry = (List<Object>)obj;
        String key = (String)entry[0];
        Integer value = Integer.valueOf(entry[1]);
        facilityMap.put(key, value);
    }
      
        System.debug('UpdateExistingCapacity=> '+facilityMap);
        set<ID>FacilityIds = new set<Id>();
        for(hed__Facility__c facility : facilityList)
        {
            FacilityIds.add(facility.Id);
        }
        Map<Id,hed__Facility__c>RemoveExistingFacility = new Map<Id,hed__Facility__c>();
        for(hed__Facility__c ht: facilityList)
        {
            RemoveExistingFacility.put(ht.Id,ht);
        }
        try {
            set<String>EligibleSRNS = new set<String>();
            set<String>InEligibleSRNS = new set<String>();
            for(String srn : EligibleStudents)
            {
                EligibleSRNS.add(srn);
            }
            for(String srn : InEligibleStudents)
            {
                InEligibleSRNS.add(srn);
            }

           
            List<IA_Seating_Room_Allotment__c> allotmentsToInsert = new List<IA_Seating_Room_Allotment__c>();

            // Parse exam time string to Time instance
            Time formattedTime = parseTime(examTime);
            System.debug('FormattedTime=> '+formattedTime);
            
            hed__Program_Plan__c Ht = [Select Id,hed__Account__c from hed__Program_Plan__c where Id=:ActiveProgramBatch];
            
            
            // Query for existing seating room allotments based on date, shift, and account
            List<IA_Seating_Room_Allotment__c> existingAllotments = [SELECT Id, Name, Remaining_Capacity__c,Alloted_Students__c,InEligible_SRN__c,Total_Students__c,Facility_Type__c,Capacity__c,Assigned_Program_Batches__c
                                                                     FROM IA_Seating_Room_Allotment__c
                                                                     WHERE rve_Date_of_Exam__c = :dateOfExam AND rveShift__c = :shift AND School__c = :Ht.hed__Account__c AND Exam_Time__c=:formattedTime and Facility_Type__c In:FacilityIds];
            
            System.debug('ExistingAllotments=> '+existingAllotments);

            if (!existingAllotments.isEmpty()) {
                for (Integer i = 0; i < facilityList.size(); i++) {
                    if (RemoveExistingFacility.containskey(facilityList[i].Id)) {
                        facilityList.remove(i);
                        // If you want to remove only the first occurrence, you can break here
                    }
                }
                // If existing allotments found, update them
                for (IA_Seating_Room_Allotment__c allotment : existingAllotments) {
                    System.debug('Capacity=> '+allotment.Capacity__c);
                
                    String EligibleContacts = '';
                    String InEligibleContacts = '';
                    Integer remainingStudentsCount = EligibleStudents.size() + InEligibleStudents.size(); // Total number of students to allot
                    Integer remainingCapacity = Integer.valueOf(facilityMap.get(allotment.Facility_Type__c));
                    System.debug('remainingCapacity=> '+remainingCapacity);
                    Set<String> assignedEligibleContacts = new Set<String>(); // Contacts assigned to this room
                    Set<String> assignedInEligibleContacts = new Set<String>(); 
                    // Check if there is available capacity
                        // Assign eligible students to the current room
                        System.debug('EligibleSRNS=> '+EligibleSRNS.size());

                if(!EligibleSRNS.isEmpty()){
                    for (String contact : EligibleSRNS) {
                        if (remainingCapacity <= 0) break;
                        assignedEligibleContacts.add(contact);
                        remainingCapacity--;
                        remainingStudentsCount--; // Decrement remaining students count
                    }
                    Integer countEligibleSRNS = 0;
                    for(String s : assignedEligibleContacts)
                    {
                    EligibleContacts+= s;
                    countEligibleSRNS++;
                    if (countEligibleSRNS < assignedEligibleContacts.size()) {
                        EligibleContacts += ',';
                    }
                    EligibleSRNS.remove(s);
                    }

                if(EligibleSRNS.isEmpty() && !InEligibleSRNS.isEmpty()){
                    System.debug('315=> '+InEligibleSRNS);
                    for (String contact : InEligibleSRNS) {
                        if (remainingCapacity <= 0) break;
                        assignedInEligibleContacts.add(contact);
                        remainingCapacity--;
                        remainingStudentsCount--; // Decrement remaining students count
                    }
                    Integer countInEligibleSRNS = 0;
                    for(String s : assignedInEligibleContacts)
                    {
                    InEligibleContacts+= s;
                    countInEligibleSRNS++;
                    if (countInEligibleSRNS < assignedInEligibleContacts.size()) {
                        InEligibleContacts += ',';
                    }
                    InEligibleSRNS.remove(s);
                    }
                }

        System.debug('EligibleContacts=> '+EligibleContacts);

        List<String> stringList = EligibleContacts.split(',');

        Integer sizeOfStringList = stringList.size();
         System.debug('Size of the list: ' + sizeOfStringList);

         System.debug('InEligibleContacts=> '+InEligibleContacts);

        List<String> stringList2 = InEligibleContacts.split(',');

        Integer sizeOfStringList2 = stringList2.size();
         System.debug('Size of the list2: ' + sizeOfStringList2);
                    // Create allotment record if there are eligible or ineligible students assigned to this room
                    if (!assignedEligibleContacts.isEmpty()) {
                        allotment.Alloted_Students__c = (String.isNotBlank(allotment.Alloted_Students__c)) ? allotment.Alloted_Students__c + ',' + EligibleContacts : EligibleContacts;
                        if(!String.isEmpty(InEligibleContacts))
                        {
                        allotment.InEligible_SRN__c = (String.isNotBlank(allotment.InEligible_SRN__c)) ? allotment.InEligible_SRN__c + ',' + InEligibleContacts : InEligibleContacts;
                        }
                        allotment.Assigned_Program_Batches__c = (String.isNotBlank(ActiveProgramBatch)) ? allotment.Assigned_Program_Batches__c + ',' + ActiveProgramBatch : ActiveProgramBatch;
                        allotment.Total_Students__c += (assignedEligibleContacts.size()+assignedInEligibleContacts.size());
                        allotment.End_Time__c = EndTime;
                        allotment.Course_Name__c = TimeTable.Course__r.Name!=null?TimeTable.Course__r.Name:'';
                        allotment.Exam_Name__c = TimeTable.Reva_Exam_Notification__r.Name!=null?TimeTable.Reva_Exam_Notification__r.Name:'';
                        // assignStudentsToAllotment(allotment, assignedContacts);
                       System.debug('allotment=> '+allotment.Total_Students__c);
                       allotmentsToInsert.add(allotment);
                    }
                       
                        System.debug('remainingStudentsCount=> '+remainingStudentsCount);
                        if (remainingStudentsCount <= 0) break;

                    }
                    if (!allotmentsToInsert.isEmpty()) {
                        update allotmentsToInsert;
                    }
        
                    // Check if all students are allotted
                     
                }
            }
                 if(!EligibleSRNS.isEmpty() || !InEligibleSRNS.isEmpty()) {

                    System.debug('EligibleSRNS=> '+EligibleSRNS.size());
                    System.debug('InEligibleSRNS=> '+InEligibleSRNS.size());

                    
                  //  System.debug('No available capacity in allotment ' + allotment.Id);
                    // Create new allotments for remaining students
                    createAllotments(activeProgramBatch,facilityMap, facilityList,EligibleSRNS,InEligibleSRNS, dateOfExam, shift, formattedTime,EndTime,TimeTable.Course__r.Name,TimeTable.Reva_Exam_Notification__r.Name);
                }
                return 'Allotments created or updated successfully';

        } 

    catch (Exception e) {
            System.debug('Line=> '+e.getLineNumber()+ ' Exception: ' + e.getMessage());
            return e.getMessage();
        }
    }
    
    private static Map<Id, Integer> getAttendancePercentages(List<Contact> students) {
        Map<Id, Integer> attendancePercentages = new Map<Id, Integer>();
        try {
            List<hed__Program_Enrollment__c> enrollmentRecords = [SELECT hed__Contact__c, Attendance_Percentage__c FROM hed__Program_Enrollment__c WHERE hed__Contact__c IN :students];
            for (hed__Program_Enrollment__c enrollmentRecord : enrollmentRecords) {
                attendancePercentages.put(enrollmentRecord.hed__Contact__c, Integer.valueOf(enrollmentRecord.Attendance_Percentage__c));
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
        return attendancePercentages;
    }
    
    public static String createAllotments(String ActiveProgramBatch,Map<String,Integer>FacilityMap, List<hed__Facility__c> facilityList, Set<String> EligibleStudents, Set<String> InEligibleStudents, Date dateOfExam, String shift, Time examTime,Time EndTime,String CourseName, String ExamName) {
        try {
            System.debug('CreateAllotments' + ActiveProgramBatch + ' DateOfExam=> ' + dateOfExam + ' shift=> ' + shift + ' ExamTime=> ' + examTime);
            System.debug('facilities=> ' + facilityList);
            List<IA_Seating_Room_Allotment__c> allotmentsToInsert = new List<IA_Seating_Room_Allotment__c>();
            Set<String> allottedSRNs = new Set<String>(); // To track allotted SRN numbers
            Integer remainingStudentsCount = EligibleStudents.size() + InEligibleStudents.size(); // Total number of students to allot
            // Map to store contacts assigned to each room
            Map<hed__Facility__c, Set<Contact>> assignedContactsMap = new Map<hed__Facility__c, Set<Contact>>();
            String EligibleSRNs = '';
            String InEligibleSRNS = '';
    
            // Collection to hold remaining SRNs for the next room assignment
            Set<String> remainingSRNs = new Set<String>();
    
            for (hed__Facility__c facility : facilityList) {
                Integer remainingCapacity = Integer.valueOf(facilityMap.get(facility.Id));
                Set<String> assignedEligibleContacts = new Set<String>(); // Contacts assigned to this room
                Set<String> assignedInEligibleContacts = new Set<String>(); // Contacts assigned to this room
    
                System.debug('EligibleSRn=> ' + EligibleStudents.size());
                System.debug('InEligibleSRn=> ' + InEligibleStudents.size());
    
                // Assign eligible students to the current room
                if (!EligibleStudents.isEmpty()) {
                    for (String contact : EligibleStudents) {
                        if (remainingCapacity <= 0) break;
                        assignedEligibleContacts.add(contact);
                        remainingCapacity--;
                        remainingStudentsCount--; // Decrement remaining students count
                    }
    
                    Integer countEligible = 0;
                    for (String s : assignedEligibleContacts) {
                        EligibleSRNs += s;
                        countEligible++;
                        if (countEligible < assignedEligibleContacts.size()) {
                            EligibleSRNs += ',';
                        }
                        EligibleStudents.remove(s);
                    }
                    System.debug('EligibleStudents=> ' + EligibleStudents);
                }

                System.debug('Eligibleleft=> '+EligibleStudents.size()+' InEligibleleft=> '+InEligibleStudents.size());
    
                // If there are no more eligible students, assign ineligible students to the next available room
                if ((EligibleStudents.size()==0 && InEligibleStudents.size()>0)) {
                    Integer remainingInEligibleCount = remainingStudentsCount - assignedEligibleContacts.size();
                    System.debug('519=> '+remainingInEligibleCount);
                        // Assign remaining ineligible students to the next available room
                        for (String contact : InEligibleStudents) {
                            if (remainingCapacity <= 0) break;
                            assignedInEligibleContacts.add(contact);
                            remainingCapacity--;
                            remainingStudentsCount--; // Decrement remaining students count
                        }
    
                        Integer countIneligible=0;
                        for (String s : assignedInEligibleContacts) {
                            InEligibleSRNs += s;
                            countIneligible++;
                            if (countIneligible < assignedInEligibleContacts.size()) {
                                InEligibleSRNs += ',';
                            }
                            InEligibleStudents.remove(s);
                        }
                        System.debug('InEligibleStudents=> ' + InEligibleStudents);
                }
    
                // Create allotment record if there are eligible or ineligible students assigned to this room
                if (!assignedEligibleContacts.isEmpty() || !assignedInEligibleContacts.isEmpty()) {
                    IA_Seating_Room_Allotment__c allotment = new IA_Seating_Room_Allotment__c(
                        Name = facility.Room__c,
                        Facility_Type__c = facility.Id,
                        Capacity__c = facility.hed__Capacity__c,
                        IA_Type__c = facility.IA_Type__c,
                        School__c = getAccountId(ActiveProgramBatch),
                        Room__c = facility.Room__c,
                        Active__c = true,
                        rve_Date_of_Exam__c = dateOfExam,
                        rveShift__c = shift,
                        Exam_Time__c = examTime,
                        End_Time__c = EndTime,
                        Alloted_Students__c = EligibleSRNs,
                        InEligible_SRN__c = InEligibleSRNS,
                        Course_Name__c = CourseName!=null?CourseName:'',
                        Exam_Name__c = ExamName!=null?ExamName:'',
                        Assigned_Program_Batches__c = ActiveProgramBatch,
                        Total_Students__c = assignedEligibleContacts.size() + assignedInEligibleContacts.size()
                    );
                    allotmentsToInsert.add(allotment);
    
                    EligibleSRNs = '';
                    InEligibleSRNS = '';
                }
    
                // Check if all students are allotted
                if (remainingStudentsCount <= 0) break;
            }
            if (!allotmentsToInsert.isEmpty()) {
                insert allotmentsToInsert;
            }
    
            return 'Allotments created or updated successfully';
        } catch (Exception e) {
            System.debug('Line=> ' + e.getLineNumber() + ' Exception: ' + e.getMessage());
            return e.getMessage();
        }
    }
    
    public static list<contact> getEligibleStudents(String ActiveProgramBatch){
        List<contact>EligibleStudents = new List<contact>();
        List<Contact> contactsWithZeroPendingAmount = new List<Contact>();
        
        try{
            List<Contact> contacts = [SELECT Id, Name, SRN_Number__c,
                                      (SELECT Id, Amount_Pending__c FROM Student_Fees__r)
                                      FROM Contact
                                      WHERE Active__c = true and Program_Batch__c =:ActiveProgramBatch AND SRN_Number__c!=null];
            
            // Iterate through contacts
            for (Contact contact : contacts) {
                // Check if the contact has related student fees records
                if (!contact.Student_Fees__r.isEmpty()) {
                    Boolean allPendingAmountsZero = true;
                    // Iterate through related student fees records
                    for (Student_Fee__c fee : contact.Student_Fees__r) {
                        // Check if any of the student fees records have pending amount greater than zero
                        if (fee.Amount_Pending__c > 0) {
                            allPendingAmountsZero = false;
                            break;
                        }
                    }
                    // If all related student fees records have pending amount equal to zero, add the contact to the result list
                    if (allPendingAmountsZero) {
                        contactsWithZeroPendingAmount.add(contact);
                    }
                }
            }
            
            // contactsWithZeroPendingAmount now contains the list of contacts with all related student fees records having pending amount equal to zero
            System.debug('contactsWithZeroPendingAmount');
            set<ID>ContactIds = new set<ID>();
            for(Contact con: contactsWithZeroPendingAmount)
            {
                ContactIds.add(con.Id);
            }
            EligibleStudents = [Select Id,name,SRN_Number__c,MobilePhone, Father__c, Father_Name__c, Father_Mobile_Number__c,Active_Semester__r.Name,Mother_Name__c,Mother_Mobile_Number__c,Guardian__r.Name,Guardian__r.MobilePhone
                                 from Contact where Program_Batch__c =:ActiveProgramBatch and ID IN(
                SELECT hed__Contact__c 
                FROM hed__Program_Enrollment__c 
                WHERE Attendance_Percentage__c >= 75
            )and ID IN:ContactIds and Active__c=True and SRN_NUMBER__c!=null ORDER By SRN_Number__c];
            
            System.debug('EligibleStudents=>'+EligibleStudents);
            //return EligibleStudents;
            for(contact con :EligibleStudents ){
                system.debug(con.Name+'<<>>'+con.MobilePhone);
            }
            return EligibleStudents;
        }catch(Exception e){
            System.debug('Line=> '+e.getLineNumber()+' Exception=> '+e.getMessage());
            return new List<contact>();
        }
    }
    
    public static list<contact> getIneligibleStudents(String ActiveProgramBatch){
        List<contact>IneligibleStudents = new List<contact>();
        try{
            List<Contact> contactsWithLowAttendance = [SELECT Id FROM Contact
                                                       WHERE Active__c = true
                                                       AND Program_Batch__c =:ActiveProgramBatch AND SRN_Number__c!=null
                                                       AND Id IN (SELECT hed__Contact__c
                                                                  FROM hed__Program_Enrollment__c
                                                                  WHERE Attendance_Percentage__c < 75)];
            
            List<Student_Fee__c> contactsWithPendingFees = [SELECT Contact__c
                                                            FROM Student_Fee__c
                                                            WHERE Amount_Pending__c > 0 and contact__r.Program_Batch__c =:ActiveProgramBatch];
            
            Set<Id> contactIdsWithLowAttendance = new Set<Id>();
            for (Contact contact : contactsWithLowAttendance) {
                contactIdsWithLowAttendance.add(contact.Id);
            }
            
            Set<Id> contactIdsWithPendingFees = new Set<Id>();
            for (Student_Fee__c fee : contactsWithPendingFees) {
                contactIdsWithPendingFees.add(fee.Contact__c);
            }
            
            // Combine the sets to get the contacts that satisfy either condition
            contactIdsWithLowAttendance.addAll(contactIdsWithPendingFees);
            
            InEligibleStudents = [SELECT Id, Name, Program_Batch__r.Name, Primary_Academic_Program__r.Name, SRN_Number__c, Active_Semester__r.Name,
            MobilePhone, Father__c, Father_Name__c, Father_Mobile_Number__c,Mother_Name__c,Mother_Mobile_Number__c,Guardian__r.Name,Guardian__r.MobilePhone
                                  FROM Contact
                                  WHERE Id IN :contactIdsWithLowAttendance AND SRN_Number__c!=null
                                  ORDER BY SRN_Number__c];
            
            System.debug('InEligibleStudents=> '+InEligibleStudents);
              for(contact con :InEligibleStudents ){
                system.debug(con.Name+'<<>>'+con.MobilePhone);
            }
            
            return InEligibleStudents;
            
        }catch(Exception e){
            System.debug('Line=> '+e.getLineNumber()+' Exception=> '+e.getMessage());
            return new List<contact>();
        }
    }
    
    @AuraEnabled
    public static IASeatingArrangementDetails getAllStudents(String ActiveProgramBatch){
        IASeatingArrangementDetails NewInstance = new IASeatingArrangementDetails();
        
        List<contact>EligibleStudents = getEligibleStudents(ActiveProgramBatch);
        List<contact>InEligibleStudents = getInEligibleStudents(ActiveProgramBatch);
        System.debug('EligibleStudents=> '+EligibleStudents.size());
        System.debug('InEligibleStudents=> '+InEligibleStudents.size());
        Set<String>EligibleSRNS = new set<string>();
        Set<String>InEligibleSRNS = new set<string>();

        for(contact con: EligibleStudents)
        {
            EligibleSRNS.add(con.SRN_Number__c);
        }
        for(contact con: InEligibleStudents)
        {
            INEligibleSRNS.add(con.SRN_Number__c);
        }
        NewInstance.EligibleStudents = EligibleSRNS;
        NewInstance.InEligibleStudents = INEligibleSRNS;
        NewInstance.SizeOfStudents=0;
        if(!EligibleStudents.isEmpty() || !InEligibleStudents.isEmpty())
        {
            NewInstance.SizeOfStudents = (NewInstance.EligibleStudents.size()+NewInstance.InEligibleStudents.size());
        }
        return NewInstance; 
    }
    
    @AuraEnabled
    public static String getAccountId(String ProgramBatch){
        System.debug('getAccountIdCalled=> '+ProgramBatch);
        String AccountId;
        try {
            hed__Program_Plan__c ht = [SELECT hed__Account__c FROM hed__Program_Plan__c where Id=:ProgramBatch limit 1];
            AccountId = ht.hed__Account__c;
            System.debug('AccountId=> '+AccountId);
        } catch (Exception e) {
            System.debug('Line=> '+e.getLineNumber()+' Exception=> '+e.getMessage());
        }
        return AccountId;
    }
}