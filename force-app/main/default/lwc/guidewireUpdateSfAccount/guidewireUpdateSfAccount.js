import { LightningElement, api } from 'lwc';
import syncAccount from '@salesforce/apex/GuidewireUpdateSfAccount.syncAccount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';


export default class GuidewireUpdateSfAccount extends LightningElement {
    

     @api invoke() {
    console.log("Hi, I'm an action.");
   // For now we’re calling Apex with a fixed external ID “12345”
        console.log('Starting sync for dummy recordId 12345');
        
        
        syncAccount({ recordIdOrDummy: 'pc:12345' })
            .then(result => {
                this.showToast('Success', result, 'success');
                 // refresh the record view data
        getRecordNotifyChange([{ recordId: this.recordId }]);
        window.location.reload();

        // close the quick action
        this.closeAction();
            })
            .catch(error => {
                let errMsg = (error && error.body && error.body.message) ? error.body.message : 'Unknown error';
                this.showToast('bad Error', errMsg, 'error');
                this.closeAction();
            });
  }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    closeAction() {
        // closes the quick action panel automatically
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}