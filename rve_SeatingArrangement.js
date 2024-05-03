import { LightningElement, wire, track, api } from 'lwc';
// Import from Apex
 import getActivePrograms from '@salesforce/apex/rveSeatingArrangementUpdated.getActivePrograms';
 import getRelatedSchool from '@salesforce/apex/rveSeatingArrangementUpdated.getRelatedSchool';
 import createOrUpdateAllotment from '@salesforce/apex/rveSeatingArrangementUpdated.createOrUpdateAllotment';
 import getRevaExamNotifications from '@salesforce/apex/rveSeatingArrangementUpdated.getRevaExamNotifications';
 import getAllStudents from '@salesforce/apex/rveSeatingArrangementUpdated.getAllStudents';
 import updateFacilities from '@salesforce/apex/rveSeatingArrangementUpdated.updateFacilities';
 import checkProgramBatchAllotment from '@salesforce/apex/rveSeatingArrangementUpdated.checkProgramBatchAllotment'
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class Rve_SeatingArrangement extends LightningElement {

    // Variables related to account and school
    @track parentAccountId;
    @track ProgramBatch;
    @track ProgramOption = [];
    
    // Variables related to facilities and seating arrangements
    @track DisplayFacility=false;
    @track facilitiesList = [];
    @track seatingArrangements = [];
    @track seatingArrangementParent = [];
    @track finalAllotment = [];
    @track isModalOpen = false;
    @track showModal = false;
    @track valueToPass;
    
    // Variables related to exam details
    @track DateOfExam;
    @track IAType;
    @track Session;
    @track AllotmentDate;

    // Variables related to UI state and functionality
    @track secondcmp = false;
    @track variable1 = true;
    @track variable2 = true;
    @track EnableAllotmentButton = true;
    @track hasAvailableDates = false;

    // Variables related to time and date
    @track TimeTableDates = [];
    @track TimeTableTimes = [];
    @track timeMap = new Map();
    @track hours;
    @track DateByIA;
    @track mapData;
    @track variable=true
    @track EnableSubmitButton=true;
    @track ExamTime;
    @track EligibleStudentsCount;
    @track InEligibleStudentsCount;
    @track TotalStudents=0;
    @track DisplayStudents=false;

    get IATypesOptions() {
        return [
            { label: 'IA 1', value: 'IA 1' },
            { label: 'IA 2', value: 'IA 2' }
        ];
    }

    SessionOptions = [
        { label: 'Morning', value: 'Morning' },
        { label: 'Afternoon', value: 'Afternoon' }
    ];

    ModalOptions = [
        { label: 'Attendance Sheet', value: 'Attendance' },
        { label: 'Notice Board', value: 'Notice Board' }
    ];

     @wire(getActivePrograms)
     wiredAccounts({ error, data }) {
         if (data) {
            for(let i=0; i<data.length; i++) {
                  console.log('id=' + data[i].Id);
                 this.ProgramOption = [...this.ProgramOption ,{value: data[i].Id , label: data[i].Name}];                                   
             }
             console.log('ProgramOption=> '+this.ProgramOption);                
            this.error = undefined;
         } else if (error) {
             this.error = error;
             this.ProgramOption = undefined;
         }
         }

          SelectedProgramBatch(event){
            console.log('Selected School: '+event.target.value);
             this.ProgramBatch = event.target.value;
        }

        handleIATypeChange(event) {
            this.IAType = event.target.value;
            const IAType = event.target.value;
            console.log('IAType=> '+this.IAType);
                    const index = event.target.dataset.id;
                    console.log('index=> '+index);
                    this.seatingArrangements.forEach(e => {
                            
                                    e.IA_Type__c = IAType;
                                    console.log('260=> '+e.IA_Type__c);
                            
                    });
                    if(this.IAType!=null && this.Session!=null)
                    {
                        this.handleDateBasedOnIAChange();
                    }
    
                    console.log(JSON.stringify(this.seatingArrangements));
        }

        SelectedDate(event){
            console.log('Selected Date=> '+event.target.value);
            this.EnableSubmitButton = false
            this.DateOfExam = event.target.value;

         }

        handleSession(event){
            console.log('196=> '+event.target.value);
            console.log('ProgramId=> '+this.ProgramBatch)
            this.Session = event.target.value;
            getRevaExamNotifications({
                IAType:this.IAType,
                Session:this.Session,
                ProgramId:this.ProgramBatch
            }).then(res=>{
            if(res.length>0)
            {
                this.DateByIA = '';
             //   this.TimeTableTimes=[];
                this.timeMap.clear();
    
                console.log('Data=> '+JSON.stringify(res));
        
                for(let i=0;i<res.length;i++)
                {
                    const exists = this.TimeTableDates.find(entry => entry.value === res[i].hed_Date__c);
                    console.log('140=> '+exists);
    
                    if (!exists) {
                        this.TimeTableDates = [...this.TimeTableDates, { value: res[i].hed_Date__c, label: res[i].hed_Date__c }];
                        let hours = Math.floor(res[i].hed_Start_Time__c / (1000 * 60 * 60));
                        let minutes = Math.floor((res[i].hed_Start_Time__c % (1000 * 60 * 60)) / (1000 * 60));
                        let seconds = Math.floor((res[i].hed_Start_Time__c % (1000 * 60)) / 1000);
                    
                        // Add leading zeros if necessary
                        hours = (hours < 10) ? "0" + hours : hours;
                        minutes = (minutes < 10) ? "0" + minutes : minutes;
                        seconds = (seconds < 10) ? "0" + seconds : seconds;
                    
                        // Add AM or PM based on hours
                        let ampm = (hours >= 12) ? "PM" : "AM";
                        hours = (hours % 12 === 0) ? 12 : hours % 12; // Convert 0 to 12 for 12-hour format
                    
                        // Construct the formatted time string
                        let formattedTime = hours + ":" + minutes + ":" + seconds + " " + ampm;
                    this.TimeTableTimes = [...this.TimeTableTimes,{value:formattedTime,label:formattedTime}]
                    
                    }
                    console.log('TimeTableTimes=> '+this.TimeTableTimes);
                    this.timeMap.set(res[i].hed_Date__c, res[i].hed_Start_Time__c);
                }
            }
            else{
                this.DateByIA=''
                this.TimeTableDates=[];
                this.TimeTableTimes=[];
                this.timeMap.clear();
                console.log('No Date Found');
                this.ToastEvent('No Active Time Table with selected Input','warning');

            }
        })
        }

        handleTime(event){
          console.log('Time=> '+event.target.value)
          this.ExamTime = event.target.value;
        }

        SearchFacility() {
            checkProgramBatchAllotment({
                ActiveProgramBatch: this.ProgramBatch,
                dateOfExam: this.DateOfExam,
                shift: this.Session,
                examTime: this.ExamTime
            })
            .then(res => {
                console.log('res=> ' + res);
                if (res === 'found') {
                    this.ToastEvent('Program Batch Already Alloted', 'error');
                } else {
                    getAllStudents({
                        ActiveProgramBatch: this.ProgramBatch
                    })
                    .then(res => {
                        console.log('StudentCount=> ' + res.SizeOfStudents);
                        this.DisplayStudents = true;
                        this.EligibleStudentsCount = res.EligibleStudents.length;
                        this.InEligibleStudentsCount = res.InEligibleStudents.length;
                        this.TotalStudents = this.EligibleStudentsCount + this.InEligibleStudentsCount;
                        console.log('Eligible=> ' + this.EligibleStudentsCount);
                        console.log('InEligible=> ' + this.InEligibleStudentsCount);
                    })
                    .catch(error => {
                        console.error('Error fetching students: ', error);
                    });
        
                    this.seatingArrangements = [];
                    if (this.ProgramBatch && this.IAType && this.Session && this.DateOfExam && this.ExamTime) {
                        getRelatedSchool({
                            ProgramBatchId: this.ProgramBatch,
                            IAType: this.IAType,
                            Session: this.Session,
                            DateOfExam: this.DateOfExam,
                            ExamTime: this.ExamTime
                        })
                        .then(res => {
                            console.log('res: ', res);
                            let k = 0;
                            this.facilitiesList = res;
                            console.log('facilitiesList: ', this.facilitiesList);
                            for (let i of this.facilitiesList) {
                                this.DisplayFacility = true;
                                k++;
                                console.log('Object ' + k + ':', i);
                                console.log('RoomNo:', i.RoomNo);
                                console.log('FacilityId:', i.FacilityId);
                                console.log('Block:', i.Block);
                                console.log('Floor:', i.Floor);
                                console.log('Capacity:', i.Capacity);
        
                                const seatArrang = {
                                    index: k,
                                    Id: i.FacilityId,
                                    Name: i.RoomNo,
                                    IA_Type__c: this.IAType,
                                    Room__c: i.RoomNo,
                                    Block__c: i.Block,
                                    Floor__c: i.Floor,
                                    hed__Capacity__c: i.Capacity,
                                    Remaining_Capacity__c: i.RemainingCapacity,
                                    Capacity_Needed__c: i.RemainingCapacity,
                                    Active__c: false,
                                    rveShift__c: i.rveShift__c,
                                    Ischanged: false
                                };
                                this.seatingArrangements.push(seatArrang);
                            }
                        })
                        .catch(error => {
                            console.error('Error fetching facilities: ', error);
                        });
                    }
                }
            })
            .catch(error => {
                console.error('Error checking program batch allotment: ', error);
            });
        }
        
        handleInputChange(event) {
            console.log('81=> '+event.target.dataset.id);
            let index = event.target.dataset.id;
            let fieldName = event.target.label;
            let value = event.target.value;
            console.log('index=> '+index+' '+fieldName+' '+'value=> '+value)
            this.seatingArrangements.forEach(e => {
                if(e.index == index) {
                        e.Capacity_Needed__c = value;
                        e.Ischanged = true
                }
        });
        }

    handleActiveCheckBoxChange(event) {
        const Active = event.target.checked;
        console.log('Active=> '+Active)
        const index = event.target.dataset.id;
        this.seatingArrangements.forEach(e => {
                if(e.index == index) {
                        e.Active__c = Active;
                }
        });
        console.log('after end input---');
        console.log(JSON.stringify(this.seatingArrangements));
}

    handleDateBasedOnIAChange(){
        getRevaExamNotifications({
            IAType:this.IAType,
            Session:this.Session,
            ProgramId:this.ProgramBatch
        }).then(res=>{
        if(res.length>0)
        {
            this.DateByIA=''
            this.timeMap.clear();

            console.log('Data=> '+JSON.stringify(res));
    
            for(let i=0;i<res.length;i++)
            {
                const exists = this.TimeTableDates.find(entry => entry.value === res[i].hed_Date__c);

                if (!exists) {
                    this.TimeTableDates = [...this.TimeTableDates, { value: res[i].hed_Date__c, label: res[i].hed_Date__c }];

                }
                this.timeMap.set(res[i].hed_Date__c, res[i].hed_Start_Time__c);
            }
        }
        else{
            this.DateByIA=''
            this.timeMap.clear();
            console.log('No Date Found');
            this.ToastEvent('No Active Time Table with selected Input','warning');
        }
    })
    }

    handleSubmit(){
        let finalSeatingArrangment = []
        finalSeatingArrangment = this.seatingArrangements.filter(facility => facility.Active__c);
        let ShiftType = ''
        
        console.log('Final=> '+JSON.stringify(finalSeatingArrangment));

        let roomcapacities=0;
				
        let facilityMap = new Map();
        for (let i of finalSeatingArrangment) {
            console.log('Ischanged: ' + i.Ischanged);
            if (i.Ischanged) {
                roomcapacities+=parseInt(i.Capacity_Needed__c)

                // Parse capacity to integer and handle parsing errors
                let capacity = parseInt(i.Capacity_Needed__c);
                if (!isNaN(capacity)) {
                    facilityMap.set(i.Id, capacity);
                    console.log('Added to facilityMap: ' + i.Id + ', Capacity: ' + capacity);
                    console.log('326=> '+typeof i.Id, 'CapacityType=> '+typeof capacity);
                } else {
                    console.error('Invalid capacity for record with Id ' + i.Id + ': ' + i.Capacity_Needed__c);
                }
            }
            else{
                facilityMap.set(i.Id, parseInt(i.Remaining_Capacity__c));
                roomcapacities+=parseInt(i.Remaining_Capacity__c)
            }
            delete i.Ischanged;
        }
        
        console.log('facilityMap: ' + Array.from(facilityMap));
        console.log('facilityMap size: ' + facilityMap.size);
        
				
		if(facilityMap.size>0)
		{
			updateFacilities({
                FacilityWithUpdatedCapacity:facilityMap,
                ProgramBatchId:this.ProgramBatch
            })	
            .then(res=>{
                console.log('res=> '+res);
            })				
		}
    
        console.log('roomcapacities=> '+roomcapacities);

        console.log('ProgramBatch=> '+this.ProgramBatch)

        getAllStudents({
            ActiveProgramBatch:this.ProgramBatch
        })
        .then(res=>{
            console.log('StudentCount=> '+res.SizeOfStudents);
           
            let EligibleStudents = [...res.EligibleStudents]
            let InEligibleStudents = [...res.InEligibleStudents]
            console.log('Eligible=> '+EligibleStudents);
            console.log('InEligible=> '+InEligibleStudents);

            if(res.SizeOfStudents<=roomcapacities)
            {

                let dateObject = new Date(this.DateOfExam);
        console.log('DateOfObject'+dateObject);
        let formattedDate = dateObject.toISOString().substring(0, 10);
        console.log('Formatted Date: ' + formattedDate);
        console.log(typeof formattedDate);
        console.log('242=> '+typeof this.timeMap.get(formattedDate));

        let key;

        // Iterate over the entries of the timeMap
        for (let [date1, value] of this.timeMap.entries()) {
            // Check if the value matches the formatted date
            if (date1 === formattedDate) {
                console.log('Key250=> '+date1)
                // If match found, assign the key to the date variable and break out of the loop
                key = date1;
                break;
            }
        }

        // Print the key
        console.log('Key:',typeof key);
        console.log(this.timeMap);
        if(this.timeMap.has(formattedDate))
        {
            console.log('240'+this.timeMap.get(formattedDate))
             this.hours = Math.floor(this.timeMap.get(formattedDate) / (1000 * 60 * 60));
            console.log('Hour=> '+this.hours);
            const isBeforeNoon = this.hours < 12;
    
            if (isBeforeNoon) {
                ShiftType = 'Morning';
            } else {
                ShiftType = 'Afternoon';
            }
        }
console.log('346final=> '+finalSeatingArrangment);
console.log('411facilityMap: ' + Array.from(facilityMap));

createOrUpdateAllotment({
    ActiveProgramBatch:this.ProgramBatch,
    UpdateExistingCapacity:Array.from(facilityMap),
    facilityList:finalSeatingArrangment,
    EligibleStudents:EligibleStudents,
    InEligibleStudents:InEligibleStudents,
    dateOfExam:dateObject,
    shift:ShiftType,
    examTime:this.ExamTime
        })
        .then(res=>{
            console.log('Res=> '+JSON.stringify(res))
            if(res=='Record Exist')
            {
            this.ToastEvent('Room Allotment already Exist','error');
            }
            if(res=='Allotments created or updated successfully'){
                this.ToastEvent('Room Alloted Successfully','success');
                setTimeout(() => {
                    window.location.reload();
                }, 2000);
            }
           else{
             this.ToastEvent('Something went wrong','error');
           }
        })
        this.EnableAllotmentButton = false
        
            }
            else{
                this.ToastEvent('Selected Room Capacity is not enough for students','error')

            }
        })
        .catch(error => {
            console.error('Error fetching facilities: ', error);
            this.ToastEvent(error,'error')
        });
     }

        ToastEvent(msg,variant){
            const event = new ShowToastEvent({
                                    title: 'Seating Room Status',
                                    message: msg,
                                    variant: variant
                                });
                                this.dispatchEvent(event);
          }
            openModal() {  
        this.showModal = true;
    }
    
       handleDataPassed(event) {
       this.showModal = event.detail.data;
       console.log('show data',this.showModal);
        // Do something with passedData
    }  

    openVfPage() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleType(event){
        console.log('235=> '+event.target.value)
        this.valueToPass = event.target.value;
    }
    
    handleAllotmentDate(event){
        console.log('330=> '+event.target.value);
        this.AllotmentDate = event.target.value
    }

    RenderAttendancePdf(){
        const vfPageUrl = '/apex/RoomAllotmentPdf?renderAs=pdf&DatePass=' + encodeURIComponent(this.AllotmentDate);

        // Open the URL in a new browser window
        window.open(vfPageUrl, '_blank');
    }

    RenderNoticeBoardPdf(){
        const vfPageUrl = '/apex/NoticeBoardPdf?renderAs=pdf&DatePass=' + encodeURIComponent(this.AllotmentDate);

        // Open the URL in a new browser window
        window.open(vfPageUrl, '_blank');
    }
    }