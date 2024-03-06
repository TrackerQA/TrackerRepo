import { LightningElement, api, track } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import DEPENDENCIES_OBJECT from '@salesforce/schema/TKR_User_Story_Dependencies__c';
import CHILD_FIELD from '@salesforce/schema/TKR_User_Story_Dependencies__c.Child_User_Story__c';
import PARENT_FIELD from '@salesforce/schema/TKR_User_Story_Dependencies__c.Parent_User_Story__c';
import { refreshApex } from '@salesforce/apex';
export default class Tkr_CreateUserStoryDependencyModal extends LightningElement {
    @api showModal =false;
    @api buttonClicked;
    @api userStoryId;
    @track parentId;
    @track childId;
    @api showSpinner;
    childAPIName = CHILD_FIELD;
    objectAPIName = DEPENDENCIES_OBJECT;
    parentAPIName = PARENT_FIELD;

    //This method is called when the record edit form is load 
    handleLoad(event){
        if(this.showSpinner){
           this.showSpinner = false;
        }
        if(this.buttonClicked.includes('Parent')){
            this.childId = this.userStoryId;
        }else{
            this.parentId = this.userStoryId;
        }
    }
     
    //This method is called when the record edit form Saves the data successfully
     handleSuccess(event) {
         this.dispatchEvent(new CustomEvent('close'));
         const evt = new ShowToastEvent({
             title: "Success",
             message: "User Story created successfully",
             variant: "success"
         });
         this.dispatchEvent(evt);
         this.dispatchEvent(new CustomEvent('refresh'));
     }

     //This method is called when the record edit form Submits the data successfully to server
     handleSubmit(event){
        this.template.querySelector('lightning-record-edit-form').submit();
     }
    
     //This method is called when the modal is closed
    closeModal(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}