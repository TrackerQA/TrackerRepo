/**
* Class Name    : TKR_WorkloadManagerController
* Owner         : DELOITTE
* Created Date  : 11/04/2022
* Description   : Controller class for Workload Manager functionality
**/
public with sharing class TKR_WorkloadManagerController {
    @TestVisible private static final List<Schema.SObjectField> userStoryFieldsToBeAccessed;
    @TestVisible private static final List<Schema.SObjectField> ticketFieldsToBeAccessed;
    @TestVisible private static final Map<String, String> mapFieldTypeToLwcFieldType;
    @TestVisible private static final String TASKLIST_FIELDSET = TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_WorkloadManagerTaskListFields';
    @TestVisible private static final String REFERENCE = 'REFERENCE';
    @TestVisible private static final String DIRECT = 'DIRECT';
    @TestVisible private static final String NAME = 'Name';
    @TestVisible private static final String USERSTORY_FIELDSET = TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_WorkloadManagerUserStoryFields';
    @TestVisible private static final String TICKET_FIELDSET = TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_WorkloadManagerTicketFieldSet';
    public static List<String> additionalFields;
    public static List<String> taskFields;
    public static Map<String,String> mapTaskFields;
    public static Map<String,String> mapTaskFieldsType;
    public static Map<String,String> mapTaskFieldsDataType;

    static {
        userStoryFieldsToBeAccessed = new List<Schema.SObjectField>{
            TKR_User_Story__c.Name,
            TKR_User_Story__c.Allocated_Sprint_Rank__c,
            TKR_User_Story__c.Proposed_Sprint_Rank__c,
            TKR_User_Story__c.As_A__c,
            TKR_User_Story__c.I_Want_To__c,
            TKR_User_Story__c.So_that__c,
            TKR_User_Story__c.Allocated_Sprint__c,
            TKR_User_Story__c.Proposed_Sprint__c,
            TKR_User_Story__c.Development_Stage__c,
            TKR_User_Story__c.Allocated_Sprint_Rank_Last_Updated_By__c,
            TKR_User_Story__c.Proposed_Sprint_Rank_Last_Updated_By__c
        };
        ticketFieldsToBeAccessed = new List<Schema.SObjectField>{
            TKR_Bug__c.Name,
            TKR_Bug__c.Sprint2__c,
            TKR_Bug__c.Status__c,
            TKR_Bug__c.Problem__c,
            TKR_Bug__c.Ranked_Priority__c,
            TKR_Bug__c.Ranked_Priority_Last_Updated_By__c
        };
        mapFieldTypeToLwcFieldType = new Map<String, String>{
            REFERENCE => 'url'
        };
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         11/04/2022
    * @methodname   getUserStoriesAndTickets()
    * @description  Method to fetch the user strories and tickets which are associated with Sprint
    * @parameter    String - Sprint Id
    * @return       List<UserStoryAndTicketWrapper>
    **********************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<UserStoryAndTicketWrapper> getUserStoriesAndTickets(String sprintId) {
        List<UserStoryAndTicketWrapper> lstUsAndTkts = new List<UserStoryAndTicketWrapper>();
        Set<Id> setUsAndTktId = new Set<Id>();
        Map<Id, List<Task>> mapUsOrTktIdToTaskLst = new Map<Id, List<Task>>();

        lstUsAndTkts.addAll(getUserStories(sprintId));
        lstUsAndTkts.addAll(getTickets(sprintId));

        if (lstUsAndTkts.isEmpty()) {
            UserStoryAndTicketWrapper wrap = new UserStoryAndTicketWrapper();
            wrap.strMsgIfNoRecordAvailable = System.Label.TKR_Kanban_Board_No_Data_To_Display;
            lstUsAndTkts.add(wrap);

            return lstUsAndTkts;
        }

        for (UserStoryAndTicketWrapper wrap : lstUsAndTkts) {
            setUsAndTktId.add(wrap.usTktId);
        }

        mapUsOrTktIdToTaskLst = getTasksData(setUsAndTktId);

        for (UserStoryAndTicketWrapper wrap : lstUsAndTkts) {
            wrap.usTktTasks = mapUsOrTktIdToTaskLst.get(wrap.usTktId);
            wrap.usTktTasksLength = wrap.usTktTasks == null ? 0 : wrap.usTktTasks.size();
        }

        return lstUsAndTkts;
    }
    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         06/05/2022
    * @methodname   getTaskColumns()
    * @description  Method to fetch the columns for Dynamic Datatable for Task records
    * @parameter    
    * @return       List<TaskListColumns>
    **********************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<TaskListColumns> getTaskColumns() {
        List<TaskListColumns> columns = new List<TaskListColumns>();

        readFieldsFromFieldSet();
        for (String key : mapTaskFields.keySet()) {
            TaskListColumns column = new TaskListColumns();
            String strTaskFieldDataType = mapTaskFieldsDataType.get(key);

            column.columnApiName = key;
            column.columnLabel = mapTaskFieldsType.get(key) == REFERENCE ? mapTaskFields.get(key).substringBeforeLast(' ') : mapTaskFields.get(key); //Remove the ID keyword
            column.columnType = mapFieldTypeToLwcFieldType.containsKey(strTaskFieldDataType) ? mapFieldTypeToLwcFieldType.get(strTaskFieldDataType) : strTaskFieldDataType;
            columns.add(column);
        }

        return columns;
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         12/04/2022
    * @methodname   getUserStories()
    * @description  Method to fetch User strory records which are associated with Sprint
    * @parameter    String - Sprint Id
    * @return       List<UserStoryAndTicketWrapper>
    **********************************************************************************************/
    private static List<UserStoryAndTicketWrapper> getUserStories(String sprintId){ 
        String filterQueryStr = ' WHERE Allocated_Sprint__c=:sprintId OR Proposed_Sprint__c=:sprintId';
        String userStoryObjectType = String.valueof(TKR_User_Story__c.sobjectType);
        List<String> fieldApiName = getFieldAPiNames(userStoryFieldsToBeAccessed);
        additionalFields = new List<String>();
        for(Schema.FieldSetMember fieldSetMemberObj : readFieldSet(USERSTORY_FIELDSET, TKR_User_Story__c.sObjectType)){
            String fieldName = fieldSetMemberObj.getSObjectField().getDescribe().getName();
            additionalFields.add(fieldName);
        }
        final String queryTemplate = String.escapeSingleQuotes('SELECT ID,Allocated_Sprint__r.Name, Allocated_Sprint_Rank_Last_Updated_By__r.Name, Proposed_Sprint__r.Name, Proposed_Sprint_Rank_Last_Updated_By__r.Name, {0} FROM {1}{2} WITH SECURITY_ENFORCED ORDER BY Name');

        final String soqlQuery = String.format(
            queryTemplate, 
            new List<String> {
                String.join(fieldApiName, ', '),
                userStoryObjectType,
                filterQueryStr
            }
        );    
        List<TKR_User_Story__c> userStoryDetails = Database.query(soqlQuery);
        List<UserStoryAndTicketWrapper> userStoryList = new List<UserStoryAndTicketWrapper>();
        for(TKR_User_Story__c userStory: userStoryDetails){
            UserStoryAndTicketWrapper userStoryMapping = new UserStoryAndTicketWrapper();
            userStoryMapping.usTktId = userStory.Id;
            userStoryMapping.usTktName = userStory?.Name;
            userStoryMapping.usTktAllocatedSprintRank = userStory?.Allocated_Sprint_Rank__c;
            userStoryMapping.usTktProposedSprintRank = userStory?.Proposed_Sprint_Rank__c;
            userStoryMapping.usTktDescription = System.Label.TKR_As_a + ' ' + userStory?.As_A__c + ' ' + System.Label.TKR_I_want_to + ' ' + userStory?.I_Want_To__c + ' ' + System.Label.TKR_So_that + ' ' + userStory?.So_that__c;
            userStoryMapping.usTktAllocatedSprintId = userStory?.Allocated_Sprint__c;
            userStoryMapping.usTktAllocatedSprintName = userStory?.Allocated_Sprint__r.Name;
            userStoryMapping.usTktProposedSprintId = userStory?.Proposed_Sprint__c;
            userStoryMapping.usTktProposedSprintName = userStory?.Proposed_Sprint__r.Name;
            userStoryMapping.usTktStatus = userStory?.Development_Stage__c;
            userStoryMapping.usTktAllocatedSprintRankUpdatedBy = userStory?.Allocated_Sprint_Rank_Last_Updated_By__r.Name;
            userStoryMapping.usTktProposedSprintRankUpdatedBy = userStory?.Proposed_Sprint_Rank_Last_Updated_By__r.Name;
            userStoryMapping.usTktFieldSetFields = additionalFields;
            userStoryList.add(userStoryMapping);
        }

        return userStoryList;
    }
    
    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         12/04/2022
    * @methodname   getTickets()
    * @description  Method to fetch Ticket records which are associated with Sprint
    * @parameter    String - Sprint Id
    * @return       List<UserStoryAndTicketWrapper>
    **********************************************************************************************/  
    private static List<UserStoryAndTicketWrapper> getTickets(String sprintId){ 
        String filterQueryStr = ' WHERE Sprint2__c=:sprintId';
        String ticketObjectType = String.valueof(TKR_Bug__c.sobjectType);
        List<String> fieldApiName = getFieldAPiNames(ticketFieldsToBeAccessed);
        additionalFields = new List<String>();
        for(Schema.FieldSetMember fieldSetMemberObj : readFieldSet(TICKET_FIELDSET, TKR_Bug__c.sObjectType)){
            String fieldName = fieldSetMemberObj.getSObjectField().getDescribe().getName();
            additionalFields.add(fieldName);
        }
        final String queryTemplate = String.escapeSingleQuotes('SELECT ID,Sprint2__r.Name, Ranked_Priority_Last_Updated_By__r.Name, {0} FROM {1}{2} WITH SECURITY_ENFORCED ORDER BY Name');
        final String soqlQuery = String.format(
            queryTemplate, 
            new List<String> {
                String.join(fieldApiName, ', '),
                ticketObjectType,
                filterQueryStr
            }
        );
        List<TKR_Bug__c> ticketDetails = Database.query(soqlQuery);
        List<UserStoryAndTicketWrapper> ticketList = new List<UserStoryAndTicketWrapper>();
        for(TKR_Bug__c ticket: ticketDetails){
            UserStoryAndTicketWrapper ticketMapping = new UserStoryAndTicketWrapper();
            ticketMapping.usTktId = ticket.Id;
            ticketMapping.usTktName = ticket?.Name;
            ticketMapping.usTktAllocatedSprintId = ticket?.Sprint2__c;
            ticketMapping.usTktProposedSprintId = ticket?.Sprint2__c;
            ticketMapping.usTktAllocatedSprintName = ticket?.Sprint2__r.Name;
            ticketMapping.usTktProposedSprintName = ticket?.Sprint2__r.Name;    
            ticketMapping.usTktStatus = ticket?.Status__c;
            ticketMapping.usTktDescription = ticket?.Problem__c;
            ticketMapping.usTktAllocatedSprintRank = ticket?.Ranked_Priority__c;
            ticketMapping.usTktProposedSprintRank = ticket?.Ranked_Priority__c;
            ticketMapping.usTktAllocatedSprintRankUpdatedBy = ticket?.Ranked_Priority_Last_Updated_By__r.Name;
            ticketMapping.usTktProposedSprintRankUpdatedBy = ticket?.Ranked_Priority_Last_Updated_By__r.Name;
            ticketMapping.usTktFieldSetFields = additionalFields;
            ticketList.add(ticketMapping);
        }

        return ticketList;
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         13/04/2022
    * @methodname   getFieldAPiNames()
    * @description  Method to fetch sObject field API names
    * @parameter    NA
    * @return       List<String> - sObject field API names
    **********************************************************************************************/
    private static List<String> getFieldAPiNames(List<Schema.SObjectField> fieldsToBeAccessed){
        List<String> fieldApiNames = new List<String>();
        for(Schema.SObjectField field : fieldsToBeAccessed){
            fieldApiNames.add(field.getDescribe().getName());
        }
        return fieldApiNames;
    }
    
    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         15/04/2022
    * @methodname   getTasksData()
    * @description  Method to fetch Task records associated with User Story/Ticket
    * @parameter    User Story/Ticket Id(s)
    * @return       Map<Id, List<Task>>
    **********************************************************************************************/
    private static Map<Id, List<Task>> getTasksData(Set<Id> setUsAndTktId){
        
        Map<Id, List<Task>> mapUsOrTktIdToTaskLst = new Map<Id, List<Task>>();
        readFieldsFromFieldSet();
        String strQuery = 'SELECT ';
        for (String fieldName : taskFields) {
            strQuery += fieldName + ', ';
            if (mapTaskFieldsType.get(fieldName) == REFERENCE) {
                strQuery += (fieldName.contains('__c') ? fieldName.replace('__c', '__r.Name') : fieldName.replace('Id', '.Name')) + ', ';
            }
        }
        
        strQuery += 'Id, WhatId FROM Task WHERE WhatId IN :setUsAndTktId WITH SECURITY_ENFORCED ORDER BY CreatedDate';
        List<Task> taskList = Database.query(String.escapeSingleQuotes(strQuery));

        for(Task tsk : taskList) {
            if (!mapUsOrTktIdToTaskLst.containsKey(tsk.WhatId)) {
                mapUsOrTktIdToTaskLst.put(tsk.WhatId, new List<Task>());
            }
            mapUsOrTktIdToTaskLst.get(tsk.WhatId).add(tsk);
        }
        
        return mapUsOrTktIdToTaskLst;
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         06/05/2022
    * @methodname   readFieldsFromFieldSet()
    * @description  Method to fetch the read fields from FieldSet
    * @parameter    
    * @return       Void
    **********************************************************************************************/
    private static void readFieldsFromFieldSet() {
        taskFields = new List<String>();
        mapTaskFields = new map<String,String>();
        mapTaskFieldsType = new map<String,String>();
        mapTaskFieldsDataType = new map<String,String>();

        SObjectType sObjType = Task.sObjectType;
        DescribeSObjectResult descSobjResult = sObjType.getDescribe();

        for(Schema.FieldSetMember fieldSetMemberObj : readFieldSet(TASKLIST_FIELDSET, Task.sObjectType)) {
            String fieldName = fieldSetMemberObj.getSObjectField().getDescribe().getName();
            taskFields.add(fieldName);
            //**Start Map of Task fields API name, Label, field type
            mapTaskFields.put(fieldName, fieldSetMemberObj.getLabel());
            Schema.DisplayType fieldType = Schema.getGlobalDescribe() // or Schema.SOAPType
                                    .get('Task')
                                    .getDescribe()
                                    .fields
                                    .getMap()
                                    .get(fieldName)
                                    .getDescribe()
                                    .getType(); // or getSOAPType()

            Schema.DisplayType fieldDataType = descSobjResult.fields
                                    .getMap()
                                    .get(fieldName)
                                    .getDescribe()
                                    .getType();

            if(fieldType == Schema.DisplayType.REFERENCE){
                mapTaskFieldsType.put(fieldName, REFERENCE);
            }
            else{
                mapTaskFieldsType.put(fieldName, DIRECT);
            }

            mapTaskFieldsDataType.put(fieldName, String.valueOf(fieldDataType));
            //**End Map of Task fields API name, Label, field type
        }
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul, Swathi Badugu
    * @date         19/04/2022
    * @methodname   saveRankChanges()
    * @description  Method to update the User story (Allocated/Proposed) and/or Ticket rank
    * @parameter    Sprint Type, List of records to update
    * @return       void
    **********************************************************************************************/
    @AuraEnabled
    public static void saveRankChanges(String sprintType, String updatedRecordList){       
        List<UpdatedUserStoryAndTicketWrapper> updateWrapperList = (List<UpdatedUserStoryAndTicketWrapper>) JSON.deserialize(updatedRecordList, List<UpdatedUserStoryAndTicketWrapper>.class);
        String userId = UserInfo.getUserId();
        
        try{
            if(sprintType == 'allocated') {
                updateForAllocatedSprint(updateWrapperList, userId);
            }
            else if (sprintType == 'proposed') {
                updateForProposedSprint(updateWrapperList, userId);
            }
        }
        catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         20/04/2022
    * @methodname   updateForAllocatedSprint()
    * @description  Method to update the User story (Allocated) and/or Ticket rank
    * @parameter    List of records to update, Logged-in user Id
    * @return       void
    **********************************************************************************************/
    private static void updateForAllocatedSprint(List<UpdatedUserStoryAndTicketWrapper> updateWrapperList, String userId) {
        List<TKR_Bug__c> ticketList = new List<TKR_Bug__c>();
        List<TKR_User_Story__c> userStoryList = new List<TKR_User_Story__c>();

        List<Schema.SObjectField> fieldUserStory = new List<Schema.SObjectField>();
        fieldUserStory.add(TKR_User_Story__c.Allocated_Sprint_Rank__c);
        fieldUserStory.add(TKR_User_Story__c.Allocated_Sprint_Rank_Last_Updated_By__c);

        try {
            for(UpdatedUserStoryAndTicketWrapper wrap: updateWrapperList){
                Id usTktId = wrap.usTktId;
                String sObjName = usTktId.getSObjectType().getDescribe().getName();
                if(sObjName == (TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_Bug__c')){
                    ticketList.add(getUpdatedTicketInstance(usTktId, userId, wrap.usTktSprintRank));  
                } 
                else if(sObjName == (TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_User_Story__c') && CRUD_Check_Utility.allCreateable(fieldUserStory)){
                    TKR_User_Story__c usAllocatedSprint = new TKR_User_Story__c();
                    usAllocatedSprint.Id = usTktId;
                    usAllocatedSprint.Allocated_Sprint_Rank__c = wrap.usTktSprintRank;
                    usAllocatedSprint.Allocated_Sprint_Rank_Last_Updated_By__c = userId;
                    userStoryList.add(usAllocatedSprint);
                }
            }
            
            updateUsAndTktList(ticketList, userStoryList);
        }
        catch(Exception e) {
            throw e;
        }
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         20/04/2022
    * @methodname   updateForAllocatedSprint()
    * @description  Method to update the User story (Proposed) and/or Ticket rank
    * @parameter    List of records to update, Logged-in user Id
    * @return       void
    **********************************************************************************************/
    private static void updateForProposedSprint(List<UpdatedUserStoryAndTicketWrapper> updateWrapperList, String userId) {
        List<TKR_Bug__c> ticketList = new List<TKR_Bug__c>();
        List<TKR_User_Story__c> userStoryList = new List<TKR_User_Story__c>();

        List<Schema.SObjectField> fieldUserStory = new List<Schema.SObjectField>();
        fieldUserStory.add(TKR_User_Story__c.Proposed_Sprint_Rank__c);
        fieldUserStory.add(TKR_User_Story__c.Proposed_Sprint_Rank_Last_Updated_By__c);

        try {
            for(UpdatedUserStoryAndTicketWrapper wrap: updateWrapperList){
                Id usTktId = wrap.usTktId;
                String sObjName = usTktId.getSObjectType().getDescribe().getName();
                if(sObjName == (TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_Bug__c')){
                    ticketList.add(getUpdatedTicketInstance(usTktId, userId, wrap.usTktSprintRank));  
                } 
                else if(sObjName ==  (TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class)+'TKR_User_Story__c') && CRUD_Check_Utility.allCreateable(fieldUserStory)){
                    TKR_User_Story__c usProposedSprint = new TKR_User_Story__c();
                    usProposedSprint.Id = usTktId;
                    usProposedSprint.Proposed_Sprint_Rank__c = wrap.usTktSprintRank;
                    usProposedSprint.Proposed_Sprint_Rank_Last_Updated_By__c = userId;
                    userStoryList.add(usProposedSprint);
                }
            }

            updateUsAndTktList(ticketList, userStoryList);
        }
        catch(Exception e) {
            throw e;
        }
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         20/04/2022
    * @methodname   getUpdatedTicketInstance()
    * @description  Method to get Ticket object Instance
    * @parameter    Ticket Id, Logged-in user Id, Ticket rank
    * @return       Object - TKR_Bug__c
    **********************************************************************************************/
    private static TKR_Bug__c getUpdatedTicketInstance(Id usTktId, String userId, Decimal usTktSprintRank) {
        List<Schema.SObjectField> fieldBug = new List<Schema.SObjectField>();
        fieldBug.add(TKR_Bug__c.Ranked_Priority_Last_Updated_By__c);
        fieldBug.add(TKR_Bug__c.Ranked_Priority__c);
        if(CRUD_Check_Utility.allCreateable(fieldBug)){
            TKR_Bug__c tkt = new TKR_Bug__c();
            tkt.Id = usTktId;
            tkt.Ranked_Priority_Last_Updated_By__c = userId;
            tkt.Ranked_Priority__c = usTktSprintRank;
            return tkt;
        }
        return null;
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         20/04/2022
    * @methodname   updateUsAndTktList()
    * @description  Method to update the User story and/or Ticket records
    * @parameter    List of Ticket records, List of User story records
    * @return       void
    **********************************************************************************************/
    private static void updateUsAndTktList(List<TKR_Bug__c> ticketList, List<TKR_User_Story__c> userStoryList) {
        try {
            //Lists of objects which contains the fields for CRUD/FLS permission checks  
            List<Schema.SObjectField> fieldsTicket = new List<Schema.SObjectField>();
            List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
            if(!ticketList.isEmpty()){
                Map<String, Object> fieldToValue = ticketList[0].getPopulatedFieldsAsMap();
                // get the SObjectType
                Schema.SObjectType objectType = Schema.getGlobalDescribe().get('TKR_Bug__c');
                // get the fields on the object
                Map<String, SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
                for (String key : fieldToValue.keySet()) {
                    //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
                    if(key != 'Id')
                        fieldsTicket.add(fieldMap.get(key));
                }
            }
            if(!userStoryList.isEmpty()){
                Map<String, Object> fieldToValueUS = userStoryList[0].getPopulatedFieldsAsMap();
                // get the SObjectType
                Schema.SObjectType objectType = Schema.getGlobalDescribe().get('TKR_User_Story__c');
                // get the fields on the object
                Map<String, SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
                for (String key : fieldToValueUS.keySet()) {
                    //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
                    if(key != 'Id')
                        fieldsUserStory.add(fieldMap.get(key));
                }
            }
            SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, ticketList);
            if(!ticketList.isEmpty() && Schema.SObjectType.TKR_Bug__c.isUpdateable() && CRUD_Check_Utility.allUpdateable(fieldsTicket)){
                update securityDecision.getRecords();
            }
            SObjectAccessDecision securityDecisionUS = Security.stripInaccessible(AccessType.UPDATABLE, userStoryList);
            if(!userStoryList.isEmpty() && Schema.SObjectType.TKR_User_Story__c.isUpdateable() && CRUD_Check_Utility.allUpdateable(fieldsUserStory)){
                update securityDecisionUS.getRecords();
            }
        }
        catch(DmlException de) {
            throw de;
        }
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         06/05/2022
    * @methodname   getNamespacePrefix()
    * @description  Method to fetch the NameSpace Name
    * @parameter    
    * @return       String
    **********************************************************************************************/
    @AuraEnabled
    public static String getNamespacePrefix(){
        return TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class);
    }

    /********************************************************************************************
    * @author       Jyotirmay Paul
    * @date         06/05/2022
    * @methodname   readFieldSet()
    * @description  Method to read the FieldSet
    * @parameter    String fieldSetName, Schema.SObjectType objectName
    * @return       List<Schema.FieldSetMember>
    **********************************************************************************************/
    private static List<Schema.FieldSetMember> readFieldSet(String fieldSetName, Schema.SObjectType objectName){
        Schema.DescribeSObjectResult DescribeSObjectResultObj = objectName.getDescribe();
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.FieldSets.getMap().get(
            TKR_Utility.getNamespacePrefix(TKR_WorkloadManagerController.class) + fieldSetName
        );
        return fieldSetObj.getFields(); 
    }
    
    public class UserStoryAndTicketWrapper {
        @AuraEnabled public String usTktId;
        @AuraEnabled public String usTktName;
        @AuraEnabled public Decimal usTktAllocatedSprintRank;
        @AuraEnabled public Decimal usTktProposedSprintRank;
        @AuraEnabled public String usTktDescription;
        @AuraEnabled public String usTktAllocatedSprintId;
        @AuraEnabled public String usTktProposedSprintId;
        @AuraEnabled public String usTktAllocatedSprintName;
        @AuraEnabled public String usTktProposedSprintName;
        @AuraEnabled public String usTktStatus;
        @AuraEnabled public String usTktAllocatedSprintRankUpdatedBy;
        @AuraEnabled public String usTktProposedSprintRankUpdatedBy;
        @AuraEnabled public Integer usTktTasksLength;
        @AuraEnabled public List<Task> usTktTasks;
        @AuraEnabled public List<String> usTktFieldSetFields;
        @AuraEnabled public String strMsgIfNoRecordAvailable;
    }

    public class UpdatedUserStoryAndTicketWrapper {
        public String usTktId;
        public Decimal usTktSprintRank;
    }

    public class TaskListColumns {
        @AuraEnabled public String columnApiName;
        @AuraEnabled public String columnLabel;
        @AuraEnabled public String columnType;
    }
}