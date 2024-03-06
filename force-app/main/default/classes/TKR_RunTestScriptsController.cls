public with sharing class TKR_RunTestScriptsController {
    private static final string TKRNAMESPACE = TKR_Utility.getNamespacePrefix(TKR_RunTestScriptsController.class);

     /**
    * Method to fetch all TestExecution Records related to the user story
    * @return - List of String
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */ 
    @AuraEnabled
    public static TKR_Test__c getTestExecutionData(String testExecutionId){
        if(!String.isNotBlank(testExecutionId) || !testExecutionId.startsWith('a') || !testExecutionId.isAlphanumeric()){
            throw new IllegalArgumentException('Invalid testExecutionId: ' + testExecutionId);
        }
        return [select Id,Name, User_Story__r.Supporting_BA__c,Status__c,
                User_Story__r.Supporting_BA__r.Name, Sprint__c,Sprint__r.Name,SprintNew__c ,
                User_Story__r.Supporting_BA__r.SmallPhotoUrl, Project__c, 
                User_Story__c, Approver__c, Approver__r.Name, 
                User_Story__r.Name, Template__r.TKR_Pre_requisites__c, 
                Template__r.Expected_Result__c, Steps_Passed__c, 
                Introduction__c, Steps_Completed__c, Total_Steps__c, 
                Test_Outcome__c, Description__c, Assigned_To__c, Assigned_To__r.Name,
                Overall_Test_Comments__c, User_Story__r.User__c, 
                User_Story__r.Computer_Systems_Quality__c, 
                User_Story__r.Sprint_Tester__c, User_Story__r.User__r.Name,
                User_Story__r.Computer_Systems_Quality__r.Name, 
                User_Story__r.Sprint_Tester__r.Name 
                from TKR_Test__c where Id = :testExecutionId WITH SECURITY_ENFORCED];
    }
    
    /**
    * Method to fetch all TestExecution Records related to the user story
    * @return - List of String
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */ 
    @AuraEnabled
    public static TKR_Test_Execution_Attachments__c getAttachmentSetting(){
        return TKR_Test_Execution_Attachments__c.getInstance();
    }
    
    /**
    * Method to update the test execution record
    * @return - TKR_Test__c record
    * @see    - N/A
    * @param  - TKR_Test__c
    * @throws - N/A
    */
    @AuraEnabled
    public static TKR_Test__c updateTestExecution(TKR_Test__c testExecutionData) {
        
        system.debug('testExecutionData >' + JSON.serializePretty(testExecutionData));
        if(testExecutionData != null && Schema.sObjectType.TKR_Test__c.isUpdateable()){
            update testExecutionData;
        }
        return testExecutionData;
    }
    
    /**
    * Method to delete any record
    * @return - N/A
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static void deleteRecord(String recordId) {
        Id recordIdTemp = recordId;
        if(recordIdTemp.getSObjectType().getDescribe().isDeletable())
            Database.delete(recordId);
    }
    
    
    /**
    * Method to check the user has access to the test execution records and corresponding steps.
    * @return - true/false
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static Boolean checkReadOnly(String testUserId,String testExecutionId) {
        if(!String.isNotBlank(testExecutionId) || !testExecutionId.startsWith('a') || !testExecutionId.isAlphanumeric()){
            throw new IllegalArgumentException('Invalid testExecutionId: ' + testExecutionId);
        }
        
        TKR_Test__c testExecution = [Select Approval_Status__c from TKR_Test__c where Id = :testExecutionId WITH SECURITY_ENFORCED];
        
        UserRecordAccess access = [SELECT RecordId, HasEditAccess FROM UserRecordAccess WHERE UserId = :UserInfo.getUserId() AND RecordId = :testExecutionId WITH SECURITY_ENFORCED];
        
        //List<PermissionSetAssignment> permissionSet = [SELECT AssigneeId,PermissionSetId FROM PermissionSetAssignment where AssigneeId = :UserInfo.getUserId() and PermissionSet.Name = 'TKR_Tracker_Test_Manager'];
        if(testExecution.Approval_Status__c != 'Approved' && testExecution.Approval_Status__c != 'Pending Approval' && access.HasEditAccess == true){
            return false;
        }
        else{
            return true;
        }
    }
    
    
     /**
    * Method to insert test tickets link between text execution and ticket.
    * @return - TKR_Test_Bug_Link__c record
    * @see    - N/A
    * @param  - String, String
    * @throws - N/A
    */
    @AuraEnabled
    public static TKR_Test_Bug_Link__c insertTicketLink(String testStepId, String testExecutionId, String ticketId) {
        
        Boolean isTestBugLinkLinkCreateable = CRUD_Check_Utility.allCreateable(new SObjectField[] {
            TKR_Test_Bug_Link__c.Test_Step_Result__c,
            TKR_Test_Bug_Link__c.Bug__c,
            TKR_Test_Bug_Link__c.Test_Script__c
        });

        TKR_Test_Bug_Link__c buglink = new TKR_Test_Bug_Link__c(Test_Step_Result__c = testStepId,
        Bug__c = ticketId,
        Test_Script__c = testExecutionId);
        
        if(isTestBugLinkLinkCreateable && Schema.sObjectType.TKR_Test_Bug_Link__c.isCreateable())
        {
            insert buglink;
        }
        return buglink;
    }
    
    
    /**
    * Method to search ticket records for associate ticket functinality.
    * @return - List<TKR_Bug__c>
    * @see    - N/A
    * @param  - String, String
    * @throws - N/A
    */
    @AuraEnabled
    public static List<TKR_Bug__c> searchTicketRecords(String searchText, String testStepId) {
        /*
        string queryString = 'SELECT Id, Name, Problem__c,Problem_Description__c,User_Story__r.Name FROM TKR_Bug__c ';
        queryString += 'WHERE Id NOT IN (SELECT Bug__c from TKR_Test_Bug_Link__c where Test_Step_Result__c = \''+ String.escapeSingleQuotes(testStepId) +'\')';
        queryString += ' AND (Name LIKE \'%'+ String.escapeSingleQuotes(searchText) +'%\'';
        queryString += ' OR Problem__c LIKE \'%'+String.escapeSingleQuotes(searchText)+'%\'';
        queryString += ' OR User_Story__r.Name LIKE \'%'+String.escapeSingleQuotes(searchText)+'%\')';
        
        system.debug(queryString);
        
        return (List<TKR_Bug__c>) Database.Query(queryString);*/

        String searchString = '%' + searchText + '%';
        List<TKR_Bug__c> bugList = [SELECT Id, Name, Problem__c,Problem_Description__c,User_Story__r.Name FROM TKR_Bug__c
                                    WHERE Id NOT IN (SELECT Bug__c from TKR_Test_Bug_Link__c where Test_Step_Result__c = :testStepId)
                                    AND (Name LIKE :searchString OR Problem__c LIKE :searchString OR User_Story__r.Name LIKE :searchString) WITH SECURITY_ENFORCED];

        return bugList;
    }
    
    
    /**
    * Method to search approvers
    * @return - List<User>
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static List<User> searchApprovers(String searchText) {
        
        /*string queryString = 'SELECT Id, Name, Profile.Name, Email from User ';
        queryString += 'WHERE (Name LIKE \'%'+searchText+'%\'';
        queryString += ' OR Profile.Name LIKE \'%'+searchText+'%\'';
        queryString += ' OR Email LIKE \'%'+searchText+'%\') AND isActive = true AND ID !=\''+UserInfo.getUserId()+'\'';
        
        system.debug(queryString);
        
        return (List<User>) Database.Query(queryString);*/

        String searchString = '%' + searchText + '%';
        List<User> userList = [SELECT Id, Name, Profile.Name, Email from User 
                               WHERE (Name LIKE :searchString OR Profile.Name LIKE :searchString OR Email LIKE :searchString) WITH SECURITY_ENFORCED];
        return userList;
    }
    
    
    /**
    * Method to update test execution steps
    * @return - String
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static String updateTestExecutionSteps(String testExecutionData) {
        try{
            List<sObject> data = (List<sObject>) JSON.deserialize(testExecutionData, List<sObject>.class);
            if(data != null && !data.isEmpty()){
                //Lists of objects which contains the fields for CRUD/FLS permission checks 
                List<Schema.SObjectField> fieldssObject = new List<Schema.SObjectField>();
                Map<String, Object> fieldToValue = data[0].getPopulatedFieldsAsMap();
                Schema.sObjectType objType = data[0].getSObjectType();
                // get the SObjectType
                Schema.SObjectType objectType = Schema.getGlobalDescribe().get(string.valueOf(objType));
                // get the fields on the object
                Map<String, SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
                for (String key : fieldToValue.keySet()) {
                    //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
                    if(key != 'Id')
                        fieldssObject.add(fieldMap.get(key));
                }
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, data);
                if(objType.getDescribe().isUpdateable() && CRUD_Check_Utility.allUpdateable(fieldssObject)){
                    update securityDecision.getRecords();
                    return 'SUCCESS';
                } return 'ERROR';
            }
            return 'ERROR';
        }
        catch(Exception e){
            return 'ERROR';
        }
    }
    
    /**
    * Method to insert ticket test associations.
    * @return - String
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static String insertTicketLinkAssociation(String ticketLinkData) {
        try{
            string nameSpace = TKR_Utility.getNamespacePrefix(TKR_VisualRoadmapController.class);
            if(String.isBlank(nameSpace) && ticketLinkData.contains('DDTracker__')){
                ticketLinkData=ticketLinkData.replace('DDTracker__','');
            }
            List<sObject> data = (List<sObject>) JSON.deserialize(ticketLinkData, List<sObject>.class);
            if(data != null && !data.isEmpty()){
                //Lists of objects which contains the fields for CRUD/FLS permission checks  
                List<Schema.SObjectField> fieldssObject = new List<Schema.SObjectField>();
                Map<String, Object> fieldToValue = data[0].getPopulatedFieldsAsMap();
                Schema.sObjectType objType = data[0].getSObjectType();
                // get the SObjectType
                Schema.SObjectType objectType = Schema.getGlobalDescribe().get(string.valueOf(objType));
                // get the fields on the object
                Map<String, SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
                for (String key : fieldToValue.keySet()) {
                    //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
                    if(key != 'Id')
                        fieldssObject.add(fieldMap.get(key));
                }
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.CREATABLE, data);
                if(objType.getDescribe().isCreateable() && CRUD_Check_Utility.allCreateable(fieldssObject)){
                    insert securityDecision.getRecords();
                    return 'SUCCESS';
                }
                return 'ERROR';
            }
            return 'ERROR';
        }
        catch(Exception e){
            return 'ERROR';
        }
    }
    
    
    /**
    * Method to fetch test steps.
    * @return - List<TKR_RunTestStepsWrapper> 
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static List<TKR_RunTestStepsWrapper> getTestSteps(String testExecutionId) {

        if(!String.isNotBlank(testExecutionId) || !testExecutionId.startsWith('a') || !testExecutionId.isAlphanumeric()){
            throw new IllegalArgumentException('Invalid testExecutionId: ' + testExecutionId);
        }
        
        Map<Id, TKR_test_steps__c> testSteps = new Map<Id, TKR_test_steps__c>([select  Id,name,
                                                                                                     Sequence__c,
                                                                                                     Sequence_AS_Number__c,
                                                                                                     Action__c,
                                                                                                     Expected_Results__c,
                                                                                                     Test__r.Assigned_To__c,                                                                       
                                                                                                     Tips__c,
                                                                                                     Outcome__c,
                                                                                                     Template_Step__c,
                                                                                                     Comments__c,
                                                                                                     Related_Tickets__c,
                                                                                                     (Select Id, Name,Bug__r.Name from TKR_Case_Bug_Links__r)
                                                                                                     FROM TKR_test_steps__c
                                                                                                     WHERE test__c = : testExecutionId WITH SECURITY_ENFORCED ORDER BY Sequence_AS_Number__c]);
        
        Set<Id> ids = testSteps.keySet();
        Map<Id, List<ContentVersion>> attachments = new Map<Id, List<ContentVersion>>();

        Map<Id,Id> contentDocumentIds = new Map<Id,Id>();
        
        if(!ids.isEmpty()){
            for(ContentDocumentLink document : [SELECT Id, ContentDocumentId,LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :ids WITH SECURITY_ENFORCED]){
                contentDocumentIds.put(document.ContentDocumentId,document.LinkedEntityId);
                
            }
        }
        
        List<Id> contentversionIds = new List<Id>();
        for(ContentDocument cd : [select Id, LatestPublishedVersionId from ContentDocument where Id IN : contentDocumentIds.keySet() WITH SECURITY_ENFORCED]){
            contentversionIds.add(cd.LatestPublishedVersionId);
        }
        
        
        for(ContentVersion cv : [Select Id, Title, ContentDocumentId from ContentVersion where Id IN : contentversionIds WITH SECURITY_ENFORCED]){
            if(!attachments.containsKey(contentDocumentIds.get(cv.ContentDocumentId))){
                attachments.put(contentDocumentIds.get(cv.ContentDocumentId), new List<ContentVersion>{cv});
            }
            else{
                attachments.get(contentDocumentIds.get(cv.ContentDocumentId)).add(cv);
            }
        }
        
        List<TKR_RunTestStepsWrapper> testStepsWrapper = new List<TKR_RunTestStepsWrapper>();
        
        for(TKR_test_steps__c mapValue : testSteps.values()){
            
            testStepsWrapper.add(new TKR_RunTestStepsWrapper(mapValue.Id,
                                                         mapValue,
                                                         mapValue.TKR_Case_Bug_Links__r,
                                                         attachments.get(mapValue.Id)));
        }
        
        return testStepsWrapper;
    }
    
    
    /**
    * Method to picklist values
    * @return - TKR_RuntestPicklistWrapper object
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static TKR_RuntestPicklistWrapper getTestScriptPicklistValues(){
        
        List<TKR_SelectOptionWrapper> overallOutcomes = TKR_RunTestScriptsController.getPicklistValuesUtility('TKR_Test__c','Test_Outcome__c');
        List<TKR_SelectOptionWrapper> outcomes = TKR_RunTestScriptsController.getPicklistValuesUtility('TKR_test_steps__c','Outcome__c');
        
        system.debug('Test-> ' + overallOutcomes + '  ' + outcomes);
        
        TKR_RuntestPicklistWrapper wrapper = new TKR_RuntestPicklistWrapper(outcomes, overallOutcomes);
        
        return wrapper;
        
    }
    
    
    /**
    * Method to picklist values for create ticket component
    * @return - TKR_RuntestPicklistWrapper object
    * @see    - N/A
    * @param  - String
    * @throws - N/A
    */
    @AuraEnabled
    public static List<TKR_SelectOptionWrapper> getPicklistValues(String objectAPIName, String fieldAPIName){
        return TKR_RunTestScriptsController.getPicklistValuesUtility(objectAPIName,fieldAPIName);
    }
    
    
    
    /**
    * Method to fetch all picklist values
    * @return - List of String
    * @see    - N/A
    * @param  - String, String
    * @throws - N/A
    */ 
    public static List<TKR_SelectOptionWrapper> getPicklistValuesUtility(String objectAPIName, String fieldAPIName){
        
        List<TKR_SelectOptionWrapper> lstPicklistValues = new List<TKR_SelectOptionWrapper>();
        
        system.debug('objectAPIName -> ' + objectAPIName + ' fieldAPIName -> ' + fieldAPIName);
        
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(TKRNAMESPACE+objectAPIName);//From the Object Api name retrieving the SObject
        Sobject Object_name = targetType.newSObject();
        Schema.sObjectType sobject_type = Object_name.getSObjectType(); //grab the sobject that was passed
        Schema.DescribeSObjectResult sobject_describe = sobject_type.getDescribe(); //describe the sobject
        Map<String, Schema.SObjectField> field_map = sobject_describe.fields.getMap(); //get a map of fields for the passed sobject
        List<Schema.PicklistEntry> pick_list_values = field_map.get(TKRNAMESPACE+fieldAPIName).getDescribe().getPickListValues(); //grab the list of picklist values for the passed field on the sobject
        for (Schema.PicklistEntry a : pick_list_values) { //for all values in the picklist list
            lstPicklistValues.add(new TKR_SelectOptionWrapper(a.getLabel(),a.getValue()));//add the value  to our final list
        }
        
        return lstPicklistValues;
    }
    
    @AuraEnabled
    public static List<sObject> fetchAttachments(Id parentId){
  
        return [SELECT ContentDocumentId, ContentDocument.Title,ContentDocument.FileType,ContentDocument.description FROM ContentDocumentLink where LinkedEntityId = :parentId WITH SECURITY_ENFORCED];
        
    }
    
     /**
    * Method to fetch fields from Ticket fieldset and display on UI
    * @return - List<FieldSetWrapper> records
    * @see    - N/A
    * @param  - String, String
    * @throws - N/A
    */
    @AuraEnabled
    public static List<TKR_TicketFieldSetWrapper> readFieldSet(String fieldSetName, String ObjectName){
        List<TKR_TicketFieldSetWrapper> lstFieldSetWrapper = new List<TKR_TicketFieldSetWrapper>();
        Map<String, Schema.SObjectType> GlobalDescribeMap = Schema.getGlobalDescribe();
        Schema.SObjectType SObjectTypeObj = GlobalDescribeMap.get(TKRNAMESPACE+ObjectName);
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();        
        Map<String, Schema.SObjectField> fieldMap =  DescribeSObjectResultObj.fields.getMap();
        Map<String,Integer> mFieldLength = new Map<String,Integer>() ;
        
        for(Schema.SObjectField sObjectfield : fieldMap.values()){
            Schema.DescribeFieldResult dfield = sObjectfield.getDescribe();
            mFieldLength.put(dfield.getname(),dfield.getLength());
        }
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.FieldSets.getMap().get(TKRNAMESPACE+fieldSetName);
        system.debug('fieldSetObj'+fieldSetObj);
        for(Schema.FieldSetMember fieldSetMemberObj : fieldSetObj.getFields()){
          	String strFieldName = fieldSetMemberObj.getFieldPath();
            String strfieldType = fieldSetMemberObj.getType().name();
            if(strfieldType == 'COMBOBOX' || strfieldType == 'PICKLIST'){
                List<String> picklistValues = new List<String>();
                for(Schema.PicklistEntry ple : Schema.getGlobalDescribe().get(TKRNAMESPACE+ObjectName).getDescribe().fields.getMap().get(fieldSetMemberObj.getFieldPath()).getDescribe().getPicklistValues()){
                    picklistValues.add(ple.getValue());
                }
                lstFieldSetWrapper.add(new TKR_TicketFieldSetWrapper(fieldSetMemberObj.getFieldPath(),fieldSetMemberObj.getLabel(), fieldSetMemberObj.getRequired(), fieldSetMemberObj.getType().name(),'', picklistValues,0));
            }
            else if ( (strfieldType == 'STRING' || strfieldType == 'TEXTAREA') && mFieldLength.containsKey(strFieldName) &&  mFieldLength.get(strFieldName) != null){
               lstFieldSetWrapper.add(new TKR_TicketFieldSetWrapper(fieldSetMemberObj.getFieldPath(),fieldSetMemberObj.getLabel(), fieldSetMemberObj.getRequired(), fieldSetMemberObj.getType().name(),'' , new List<String>(),mFieldLength.get(strFieldName)));
            }
            else{
               lstFieldSetWrapper.add(new TKR_TicketFieldSetWrapper(fieldSetMemberObj.getFieldPath(),fieldSetMemberObj.getLabel(), fieldSetMemberObj.getRequired(), fieldSetMemberObj.getType().name(),'' , new List<String>(),0));
            }
        }
        system.debug('lstFieldSetWrapper'+lstFieldSetWrapper);
        return lstFieldSetWrapper;
    } 
}