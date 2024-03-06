/****************************************************************************************************************************************** 
* Class Name   : TKR_RollUpSummaryUtility
* Description  : Utility Class to Roll up values to a parent Object  
* Created By   : Deloitte Consulting
* Change Log   : Updated for v5.1.19 to add with sharing permissions
*****************************************************************************************************************************************/
public with sharing class TKR_RollUpSummaryUtility {
     
    //the following class will be used to house the field names
    //and desired operations
    public class fieldDefinition {
        public String operation {get;set;}
        public String childField {get;set;}
        public String parentField {get;set;}
         
        public fieldDefinition (String o, String c, String p) {
            operation = o;
            childField = c;
            parentField = p;
        }
    }
     
    public static void rollUpTrigger(list<fieldDefinition> fieldDefinitions,
    list<sObject> records, String childObject, String childParentLookupField, 
    String parentObject, String queryFilter) {
         
        //Limit the size of list by using Sets which do not contain duplicate
        //elements prevents hitting governor limits
        set<Id> parentIds = new set<Id>();
        //SObjectType ParentObjectType = ((SObject) Type.forName(parentObject).newInstance()).getSObjectType();
         
        for(sObject s : records) {
            parentIds.add((Id)s.get(childParentLookupField));
        }
         
        //populate query text strings to be used in child aggregrator and 
        //parent value assignment
        String fieldsToAggregate = '';
        String parentFields = '';
         
        for(fieldDefinition d : fieldDefinitions) {
            fieldsToAggregate += d.operation + '(' + d.childField + ') ' + 
            ', ';
            parentFields += d.parentField + ', ';
        }
        //Using dynamic SOQL with aggergate results to populate parentValueMap
        String aggregateQuery = 'Select ' + String.escapeSingleQuotes(fieldsToAggregate) + 
        String.escapeSingleQuotes(childParentLookupField) + ' from ' + String.escapeSingleQuotes(childObject) + ' where  ' + 
        String.escapeSingleQuotes(childParentLookupField) + ' IN :parentIds ' + queryFilter + ' WITH SECURITY_ENFORCED ' +
        ' group by ' + String.escapeSingleQuotes(childParentLookupField);
         
         system.debug('@aggregateQuery '+aggregateQuery);
        //Map will contain one parent record Id per one aggregate object
        map<Id, AggregateResult> parentValueMap = 
        new map <Id, AggregateResult>();
         
        for(AggregateResult q : Database.query(aggregateQuery)){
            system.debug('@aggregateQuery q '+q);
            parentValueMap.put((Id)q.get(TKR_Utility.getNamespacePrefix(TKR_RollUpSummaryUtility.class) + childParentLookupField), q);
        }
         
        //list of parent object records to update
        list<sObject> parentsToUpdate = new list<sObject>();
         
        String parentQuery = 'select ' + String.escapeSingleQuotes(parentFields) + ' Id ' +
         ' from ' + String.escapeSingleQuotes(parentObject) + ' where Id IN :parentIds WITH SECURITY_ENFORCED';
         system.debug('in rollupsummary '+parentQuery);
         
        //for each affected parent object, retrieve aggregate results and 
        //for each field definition add aggregate value to parent field
        for(sObject s : Database.query(parentQuery)) {
             
            Integer row = 0; //row counter reset for every parent record
            for(fieldDefinition d : fieldDefinitions) {
                String field = 'expr' + row.format();
                AggregateResult r = parentValueMap.get(s.Id);
                //r will be null if no records exist 
                //(e.g. last record deleted)
                if(r != null) { 
                    Decimal value = ((Decimal)r.get(field) == null ) ? 0 : 
                        (Decimal)r.get(field);
                    s.put(d.parentField, value);
                } else {
                    s.put(d.parentField, 0);
                }
                row += 1; //plus 1 for every field definition after first
            }
            if([SELECT RecordId, HasEditAccess FROM UserRecordAccess WHERE UserId =: userinfo.getUserId() AND RecordId =:s.Id WITH SECURITY_ENFORCED][0].HasEditAccess){
                parentsToUpdate.add(s);
            }
        }
         
  
        //if parent records exist, perform update of all parent records 
        //with a single DML statement
        if(parentsToUpdate.Size() > 0) {
             //Lists of objects which contains the fields for CRUD/FLS permission checks  
             List<Schema.SObjectField> fieldssObject = new List<Schema.SObjectField>();
             Map<String, Object> fieldToValue = parentsToUpdate[0].getPopulatedFieldsAsMap();
             Schema.sObjectType objType = parentsToUpdate[0].getSObjectType();
             // get the SObjectType
             Schema.SObjectType objectType = Schema.getGlobalDescribe().get(string.valueOf(objType));
             // get the fields on the object
             Map<String, SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
             for (String key : fieldToValue.keySet()) {
                 //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
                 if(key != 'Id')
                    fieldssObject.add(fieldMap.get(key));
             }
             SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, parentsToUpdate);
            //if(CRUD_Check_Utility.allUpdateable(fieldssObject) && ((parentObject == 'TKR_Sprint__c' && Schema.sObjectType.TKR_Sprint__c.isUpdateable())||(parentObject == 'TKR_Feature_Set__c' && Schema.sObjectType.TKR_Feature_Set__c.isUpdateable()))){
            if(objType.getDescribe().isUpdateable()  && CRUD_Check_Utility.allUpdateable(fieldssObject)){
                update securityDecision.getRecords();
            }
        }
         
    }
 
}