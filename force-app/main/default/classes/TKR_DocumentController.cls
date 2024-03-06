/****************************************************************************************************************************************** 
* Class Name   : TKR_DocumentController 
* Description  : This is a class is used to generate the Functional and Technical design documents  
* Created By   : Deloitte Consulting
* Change Log   : 16 Dec 2014: M.Richmond -  â¢  Add TKR_User_Story__r.Parent_Epic__c to SOQL on the createDocument function
*                26 Jan 2015: M.Richmond -  â¢  Update to include project name as part of SOQL filter for user story search. 
â¢  Move project select list to top of VF page TKR_DocumentGenerator 
â¢  Display an error if no project name is selected and the user presses the search button.
â¢  Update to exception error message on createQuery - Typo on the word 'wrongly'
â¢  Add some JS to theTKR_DocumentGenerator to stop the focus (screen) jumping to the first input field down in the Document Details section.
â¢  Fixed the error with the Test_TKR_DocumentController to make sure that any TKR_UserStory2Design__c insert had a related design record â This was due to the look-up on the TKR_UserStory2Design__c being changed to Master-detail.
*                19 Jun 2015: S.Holmes   -  â¢  Set to 'with sharing' for security scan 
*                23 Jun 2015: S.Holmes   -  â¢  Add EscapeSingleQuotes for security scan
*                                           â¢  Add SOQL limit for security scan in CreateQuery, createquerysoql
*                23 Aug 2015: S.Holmes   -  â¢  Add code for selecting document type 
*                23 May 2016: M.Barber   -  â¢  Security Review update: changed error message and moved SoQL +soqlwithorder to system debug log
*                                           â¢  Security Review update: Added parameters into SOQL rather than sql values
                 14 Jun 2016: H.Chauhan   -  â¢  Security Review update: Added code to check CRUD/FLS permissions for the logged in user
                 13 Apr 2017: M.Abdul Qadeer = â¢ Added functionality to incude custom fields for Functional Design Document by retrieving the fields from TKR_Functional_Design_Fields__c(Custom Setting)
                 29 June 2021: M.Barber = â¢ Added Additional Design fields to technical design query v5.1.36
*****************************************************************************************************************************************/
public with sharing class TKR_DocumentController {

    public PageReference callApex() {
        return null;
    }

    private String                          soql                    {get;set;}
    private String                          soqlwithorder           {get;set;}//to allow it to be toggled
    public list<cUS>                        lstUS                   {get;set;}
    private list<TKR_User_Story__c>         lstFullUS               {get;set;}
    public list<TKR_User_Story__c>          selectedUS              {get;set;}
    public list<TKR_User_Story__c>          unselectedUS            {get;set;}
    private set<TKR_User_Story__c>          selectedSetUS           {get;set;}
    private set<TKR_User_Story__c>          unselectedSetUS         {get;set;}
    
    public TKR_User_Story__c                initUS                  {get;set;}
    
    public list<id>                         lstSprintProposed       {get;set;}
    public list<id>                         lstSprintAllocated      {get;set;}
    public list<SelectOption>               optionsAllocatedSprint  {get;set;}
    public list<SelectOption>               optionsProposedSprint   {get;set;}
    public list<string>                     DevelopmentStage        {get;set;}
    public List<String>                     customFieldsOnUserStory {get;set;}
    public list<cUS>                        userStoriesList         {get;set;}
    public map<string,Id> MapSelOps = new Map<string,Id>();
    public map<TKR_Design__c,list<TKR_User_Story__c>> designQuery   {get;set;}  
    
    public string DevelopmentStageSOQL                              {get;set;}
    public string FunctionalAreaSOQL                                {get;set;}
    public string SubProcessSOQL                                    {get;set;}
    
    // Map added to show Functional Document .
    public map<string,list<TKR_User_Story__c>> Func_UserStory       {get;set;} 
    
    public string AuthorRole                                        {get;set;}
    public string Author                                            {get;set;}
    public string ReviewAuthorRole1                                 {get;set;}
    public string ReviewAuthor1                                     {get;set;}
    public string ReviewAuthorRole2                                 {get;set;}
    public string ReviewAuthor2                                     {get;set;}
    public string ReviewAuthorRole3                                 {get;set;}
    public string ReviewAuthor3                                     {get;set;}
    public string ReviewAuthorRole4                                 {get;set;}
    public string ReviewAuthor4                                     {get;set;}
    public string ReviewAuthorRole5                                 {get;set;}
    public string ReviewAuthor5                                     {get;set;}
    
    
    public string Project_Name {get;set;}  
    public string Deliverable_Id {get;set;}  
    public string Version{get;set;}  
    public string Change_Desp{get;set;} 
    public boolean SelectAll {get;set;}
    public string Organization {get; set;}
    public String docName{get;set;}
    public String Custom_QRCode{get;set;}
    
    public List<SelectOption> ProjNameList = new List<SelectOption>();
    public boolean DefinitionsExist {get;set;}    
    public boolean ReferencesExist {get;set;}
    private boolean hasinitrun {get;set;}
      
    public List<SelectOption> getProjNameList(){
        List<SelectOption> TempSelOpt = new List<SelectOption>();
        TempSelOpt.add(new SelectOption('', '--None--'));
        // sph 23.06.2015 add limit for security scan
        for(TKR_Project__c proj : [select id,Name from TKR_Project__c WITH SECURITY_ENFORCED limit 500]){
            TempSelOpt.add(new SelectOption(proj.Name, proj.Name));
            MapSelOps.put(proj.Name,proj.Id);
        }
        return TempSelOpt;
    }  
    
    public list<cUS> getUserStories() {
        userStoriesList = new list<cUS>();
        if (lstFullUS != null){
            for(TKR_User_Story__c s: lstFullUS) {
                userStoriesList.add(new cUS(s,SelectAll));
            }
        }
        return userStoriesList;
    }
    
    public TKR_DocumentController() {
        
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsUserStory.add(TKR_User_Story__c.Name);
        fieldsUserStory.add(TKR_User_Story__c.As_A__c);
        fieldsUserStory.add(TKR_User_Story__c.As_A_Text__c);
        fieldsUserStory.add(TKR_User_Story__c.I_Want_To__c);
        fieldsUserStory.add(TKR_User_Story__c.So_that__c);
        fieldsUserStory.add(TKR_User_Story__c.Story_Points_Total__c);
        fieldsUserStory.add(TKR_User_Story__c.Development_Stage__c);
        fieldsUserStory.add(TKR_User_Story__c.Proposed_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Allocated_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Functional_Area__c);
        fieldsUserStory.add(TKR_User_Story__c.QRCode__c);
        fieldsUserStory.add(TKR_User_Story__c.Design_Documents__c);
        
        Map<String, SObjectField> userStoryFieldsMap = SObjectType.TKR_User_Story__c.fields.getMap();
        TKR_Functional_Design_Fields__c functionalFields = TKR_Functional_Design_Fields__c.getOrgDefaults();
        customFieldsOnUserStory = new List<String>();
        System.debug('functionalFields.Value__c : ' + functionalFields.Value__c);
        System.debug('userStoryFieldsMap.keyset() : ' + userStoryFieldsMap.keySet());
        if(functionalFields != null && functionalFields.Value__c != null){
            for(String field : functionalFields.Value__c.split(' ')){
                String fieldName = field.trim().toLowerCase();
                System.debug('### Adding Field : ' + fieldName);
                if(fieldName.length() > 0 && userStoryFieldsMap.containsKey(fieldName)){
                    fieldsUserStory.add(userStoryFieldsMap.get(fieldName));
                    customFieldsOnUserStory.add(fieldName);
                }
            }
        }
        Schema.sObjectType oUserStory = TKR_User_Story__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
        if(acc.isAuthorizedToView(oUserStory, fieldsUserStory) == true)
        {
            soql = 'SELECT Name, As_A__c, As_A_Text__c, I_Want_To__c, So_that__c, Story_Points_Total__c, Development_Stage__c, Proposed_Sprint__c, Allocated_Sprint__c, Functional_Area__c,  User__r.Name, QRCode__c, Design_Documents__c ' + (customFieldsOnUserStory.isEmpty() ? '' : (', ' + String.join(customFieldsOnUserStory, ','))) + ' FROM TKR_User_Story__c WITH SECURITY_ENFORCED '; 
        }
        
        initUS = new TKR_User_Story__c();
        selectedUS = new list<TKR_User_Story__c>();
        selectedsetUS = new set<TKR_User_Story__c>();
        unselectedUS = new list<TKR_User_Story__c>();
        unselectedsetUS = new set<TKR_User_Story__c>();
        optionsAllocatedSprint = new list<selectOption>();
        optionsProposedSprint = new list<selectOption>();
        initSprint();
        selectAll = false;
        lstFullUS = Null;
        userStoriesList = Null;
        docName = '';
        hasinitrun=false;//sph 15.12.2015
        Version='1';//sph 
    }
    
    private void initSprint() {
        
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsSprint = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsSprint.add(TKR_Sprint__c.Name);
        
        Schema.sObjectType oSprint = TKR_Sprint__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
    // SPH: 12 Nov 15: Check to make sure the user has selected a project name before generating the SOQL query
        if(Project_Name == null){
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please select a Project Name'));
            return ;
        }
        lstSprintProposed = new list<id>(); 
        lstSprintAllocated = new list<id>();
        
        if(acc.isAuthorizedToView(oSprint, fieldsSprint) == true)
        {
            // sph 23.06.2015 add limit for security scan. the where for project name does not seem to work        
            for(TKR_Sprint__c s: [SELECT Name FROM TKR_Sprint__c WITH SECURITY_ENFORCED/*where Project__c=:Project_Name */ limit 500   ]) {
                optionsAllocatedSprint.add(new SelectOption(s.Id,s.Name));  
                optionsProposedSprint.add(new SelectOption(s.Id,s.Name));  
                 
            }   
        }    
        
        hasInitrun=true;//sph 15.12.2015
        
    }
    
    
    // MR: 26 Jan 15: Change this function to a pageReference so that it can return a null value as if project name is blank.
    public pageReference createQuerySOQL() {
        
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsUserStory.add(TKR_User_Story__c.Name);
        fieldsUserStory.add(TKR_User_Story__c.As_A__c);
        fieldsUserStory.add(TKR_User_Story__c.As_A_Text__c);
        fieldsUserStory.add(TKR_User_Story__c.I_Want_To__c);
        fieldsUserStory.add(TKR_User_Story__c.So_that__c);
        fieldsUserStory.add(TKR_User_Story__c.Story_Points_Total__c);
        fieldsUserStory.add(TKR_User_Story__c.Development_Stage__c);
        fieldsUserStory.add(TKR_User_Story__c.Proposed_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Allocated_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Functional_Area__c);
        fieldsUserStory.add(TKR_User_Story__c.Sub_Process__c);
        fieldsUserStory.add(TKR_User_Story__c.QRCode__c);
        fieldsUserStory.add(TKR_User_Story__c.Design_Documents__c);
        
        Schema.sObjectType oUserStory = TKR_User_Story__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
        Boolean check = false;
        
        // MR: 26 Jan 15: Check to make sure the user has selected a project name before generatin the SOQL query
        if(Project_Name == null){
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please select a Project Name'));
            return null;
        }
        system.debug('### Project_Name: '+Project_Name); 
        if(hasInitRun==false)initSprint();// need to initialise if the int has not run because the project name not selected
        
        if(acc.isAuthorizedToView(oUserStory, fieldsUserStory) == true)
        {
            check = true;
            
            // Set up SOQL
            soql = 'SELECT Name, As_A__c, As_A_Text__c, I_Want_To__c, So_that__c, Development_Stage__c, Proposed_Sprint__c, Allocated_Sprint__c, Story_Points_Total__c, Functional_Area__c, Sub_Process__c, Developer__r.Name, Supporting_BA__r.Name, User__r.Name, QRCode__c, Design_Documents__c FROM TKR_User_Story__c ';    
            
            
            if(lstSprintProposed.size() > 0) {
                soql = soql + ' WHERE Proposed_Sprint__c IN :lstSprintProposed ';
            }
            
            if(lstSprintAllocated.size() > 0) {
                if (lstSprintProposed.size() > 0){
                    soql = soql + ' AND Allocated_Sprint__c IN :lstSprintAllocated ';
                }
                else{        
                    soql = soql + ' WHERE Allocated_Sprint__c IN :lstSprintAllocated ';
                }
            }
            
            if (initUS.Development_Stage__c != null){
                String DevelopmentStageSOQL = initUS.Development_Stage__c;
                if(soql.contains('WHERE') ) {
                    soql = soql + ' AND Development_Stage__c = :DevelopmentStageSOQL ';
                }
                else {
                    soql = soql + ' WHERE Development_Stage__c = :DevelopmentStageSOQL ';
                }
            
            }
            
            if(initUS.Functional_Area__c != null) {
                String FunctionalAreaSOQL = initUS.Functional_Area__c;
                if(soql.contains('WHERE')) {
                    soql = soql +  ' AND Functional_Area__c = :FunctionalAreaSOQL';
                }
                else {
                    soql = soql +  ' WHERE Functional_Area__c = :FunctionalAreaSOQL';
                }   
            }
            
            
            if(initUS.Sub_Process__c != null) {
                String SubProcessSOQL = initUS.Sub_Process__c;
                if(soql.contains('WHERE')) {
                    soql = soql +  ' AND Sub_Process__c = :SubProcessSOQL';
                }
                else {
                    soql = soql +  ' WHERE Sub_Process__c = :SubProcessSOQL';
                }
            }
            
            
            // MR: 26 Jan 15: Add the project ID to the SOQL statement 
            // SPH: 23 Jun: add escapesinglequotes for security scan
            if(MapSelOps.get(Project_Name)  != null) {
                
                if(soql.contains('WHERE')) {
                    soql = soql +  ' AND Project__c = \'' + String.EscapeSingleQuotes(MapSelOps.get(Project_Name)) + '\' ';
                }
                else {
                    soql = soql +  ' WHERE Project__c = \'' + String.EscapeSingleQuotes(MapSelOps.get(Project_Name)) + '\' ';
                }
            }
            
            if(selectedUS.size()>0){
                list<id> selectedUSIds = new list<id>();
                soql += ' And id not in (';
                // sph 16.10.2015 add escapesingle quotes to querystring for security scan
                //for(TKR_User_Story__c us :selectedUS) soql += '\'' + us.id + '\' ,';
                for(TKR_User_Story__c us :selectedUS) soql += '\'' + String.EscapeSingleQuotes(us.id)+ '\' ,';
                soql = soql.LEFT(soql.length()-1);
                soql += ')';  
            }
            if(!soql.contains('WITH SECURITY_ENFORCED')) {       
                soql += ' WITH SECURITY_ENFORCED ';
            }    
            System.Debug('SOQL value: ' +  soql);
            System.Debug('initUS: ' + initUS);
        }
        
        // MB 23.05.2016 Moved the CreateQuery() method code to here so as to use parameters for filters in SOQL
        try {
            if(check == true)
            {
                lstFullUS = new list<TKR_User_Story__c>();
 
                soqlwithorder=soql; //generate soql string
                if(sortField != null) {
                // sph 23.06.2015 add escapesingle quotes to querystring for security scan
                    soqlwithorder = soql + String.EscapeSingleQuotes(sortField);
                 }  
                lstFullUS = Database.Query(soqlwithorder);
            
                if (lstFullUS.size()==0)
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.info, System.Label.TKR_No_Records_Found)); 
                    System.Debug('Document Generator: No Records Found' +soqlwithorder);    
            }
        } 
        catch (Exception e) {
            // MB 23.05.2016 changed error message and moved SoQL +soqlwithorder to system debug log
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, System.Label.TKR_Document_Generator_Query_Error));
            System.Debug('Document Generator SOQL Query: SOQL Query error' +soqlwithorder);
        }
        System.debug('### lstFullUS : ' + lstFullUS);
        return null;
    }
        
    public String sortDir {
        get {
             if (sortDir == null) {
                sortDir = 'ASC';
            } 
             return sortDir;
        }
        set;
    }
    
    public String sortField {
        
        get {
           string sortFieldDirString='';
            if(sortField == null) { sortField = 'Name';}
            sortFieldDirString=' order by '+ sortfield ;
            if(sortDir=='ASC'){
               return sortFieldDirString + ' ASC' ;
            }else{
               return sortFieldDirString+ ' DESC' ;
            }
            
        }
        set;
    }
    
    public void toggleSort() {
         sortDir = sortDir.equals('ASC') ? 'DESC' : 'ASC';
         // MB 23.05.2016 Moved the CreateQuery method code to here so as to use parameters for filters in SOQL
         // createQuery();
        
    }
         
    
    
    public PageReference processSelected() {        
        // Iterate through the list of US and see if they are selected, if so add them to the newly created list
        
        for(cUS cUserStory: userStoriesList) {
            if(cUserStory.selected == true) {
                // See if item is not yet in the table
                selectedSetUS.add(cUserStory.reqUS);
            }
        }
        selectedUS = new list<TKR_User_Story__c>();
        selectedUS.addAll(selectedSetUS);
        
        System.Debug('Selected List of US: ' + selectedUS);
        selectAll = false;
        return null;
    }
    
    public PageReference processUnselected() {        
        // Iterate through the list of US and see if they are unselected, if so remove them from the newly created list
        
        for(cUS cUserStory: userStoriesList) {
            if(cUserStory.selected == false) {
                // See if item is not yet in the table
                unselectedSetUS.add(cUserStory.reqUS);
            }
        }
        unselectedUS = new list<TKR_User_Story__c>();
        unselectedUS.addAll(unselectedSetUS);
        
        System.Debug('Unselected List of US: ' + unselectedUS);
        selectAll = false;
        return null;
    }
    
    public class cUS {
        public TKR_User_Story__c reqUS {get; set;}
        public Boolean selected {get; set;}
        
        public cUS(TKR_User_Story__c r) {
            reqUS = r;
            selected = false;
        }
        
        public cUS(TKR_User_Story__c r,boolean b) {
            reqUS = r;
            selected = b;
        }
    }
    
    
    // TECHNICAL DOCUMENT
    Public List<TKR_Definitions__c> Definitions {get;set;}
    Public List<TKR_References__c> References {get;set;} 
    public Pagereference createDocument() {
        
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsSprint = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsEpic = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsDesign = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsUserStoryDesign = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsDefinitions = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsProject = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsReferences = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsUserStory.add(TKR_User_Story__c.Name);
        fieldsUserStory.add(TKR_User_Story__c.Functional_Area__c);
        fieldsUserStory.add(TKR_User_Story__c.Sub_Process__c);
        
        fieldsSprint.add(TKR_Sprint__c.Name);
        
        fieldsEpic.add(TKR_Epic__c.Name);
        fieldsEpic.add(TKR_Epic__c.Epic_Details__c);
        
        fieldsDesign.add(TKR_Design__c.Name);
        fieldsDesign.add(TKR_Design__c.Overview__c);
        fieldsDesign.add(TKR_Design__c.Data_Model__c);
        fieldsDesign.add(TKR_Design__c.TKR_User_Interface_UI__c);
        fieldsDesign.add(TKR_Design__c.Objects__c);
        fieldsDesign.add(TKR_Design__c.Fields__c);
        fieldsDesign.add(TKR_Design__c.Apex_Classes__c);
        fieldsDesign.add(TKR_Design__c.Visualforce_Pages__c);
        fieldsDesign.add(TKR_Design__c.Page_Layouts__c);
        fieldsDesign.add(TKR_Design__c.Apex_Trigger__c);
        fieldsDesign.add(TKR_Design__c.Page_Layouts__c);
        fieldsDesign.add(TKR_Design__c.Other_Components__c);
        fieldsDesign.add(TKR_Design__c.RecordType.Name);
        // Added v5.1.36 June 2021        
        fieldsDesign.add(TKR_Design__c.Design_Ref__c);
        fieldsDesign.add(TKR_Design__c.Lightning_Web_Components_LWCs__c);
        fieldsDesign.add(TKR_Design__c.Process_Automation_Flows__c);
        fieldsDesign.add(TKR_Design__c.Complexity__c);

        fieldsUserStoryDesign.add(TKR_UserStory2Design__c.User_Story__c);
        
        fieldsDefinitions.add(TKR_Definitions__c.Name);
        fieldsDefinitions.add(TKR_Definitions__c.Project__c);
        fieldsDefinitions.add(TKR_Definitions__c.Term_Acronym__c);
        fieldsDefinitions.add(TKR_Definitions__c.Definition__c);
        
        fieldsProject.add(TKR_Project__c.Name);
        
        fieldsReferences.add(TKR_References__c.Name);
        fieldsReferences.add(TKR_References__c.Document_ID__c);
        fieldsReferences.add(TKR_References__c.Project__c);
        
        Schema.sObjectType oUserStory = TKR_User_Story__c.sObjectType;
        Schema.sObjectType oSprint = TKR_Sprint__c.sObjectType;
        Schema.sObjectType oEpic = TKR_Epic__c.sObjectType;
        Schema.sObjectType oDesign = TKR_Design__c.sObjectType;
        Schema.sObjectType oUserStoryDesign = TKR_UserStory2Design__c.sObjectType;
        Schema.sObjectType oDefinitions = TKR_Definitions__c.sObjectType;
        Schema.sObjectType oProjects = TKR_Project__c.sObjectType;
        Schema.sObjectType oReferences = TKR_References__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
        Definitions = new List<TKR_Definitions__c>();
        References = new List<TKR_References__c>();  
        designQuery = new map<TKR_Design__c,list<TKR_User_Story__c>>();
        list<id> idUS = new list<id>();
        Set <Id> US_With_Design = new Set<Id> ();
        List <string> US_NOT_DONE = new list <string> ();
        String Str = '';        
        if (Version != '' && Organization !='' && selectedUS.size()>0 && Project_Name != '--None--') {
            
            for(TKR_User_Story__c s: selectedUS) {
                idUS.add(s.id);
            }
            if(acc.isAuthorizedToView(oUserStory, fieldsUserStory) == true && acc.isAuthorizedToView(oSprint, fieldsSprint) == true && acc.isAuthorizedToView(oEpic, fieldsEpic) == true && acc.isAuthorizedToView(oDesign, fieldsDesign) == true && acc.isAuthorizedToView(oUserStoryDesign, fieldsUserStoryDesign) == true)
            {
                for(TKR_UserStory2Design__c u: [SELECT User_Story__c,User_Story__r.name,User_Story__r.Allocated_Sprint__r.Name,User_Story__r.Functional_Area__c,User_Story__r.Sub_Process__c, User_Story__r.Parent_Epic__r.name, User_Story__r.Parent_Epic__r.Epic_Details__c,Id, 
                                                Design__c,Design__r.name, Design__r.Overview__c, Design__r.Data_Model__c,Design__r.Design_Ref__c,Design__r.Lightning_Web_Components_LWCs__c,Design__r.Process_Automation_Flows__c,Design__r.Complexity__c, Design__r.TKR_User_Interface_UI__c, Design__r.Objects__c, Design__r.Fields__c, Design__r.Apex_Classes__c, Design__r.Visualforce_Pages__c, Design__r.Page_Layouts__c, Design__r.Apex_Trigger__c, Design__r.Other_Components__c, Design__r.RecordType.Name
                                                FROM TKR_UserStory2Design__c WHERE User_Story__c IN :idUS WITH SECURITY_ENFORCED Order By User_Story__r.name,User_Story__r.Allocated_Sprint__r.Name,User_Story__r.Functional_Area__c,User_Story__r.Sub_Process__c ]) {
                                                    if(designQuery.containsKey(u.Design__r)) {
                                                        designQuery.get(u.Design__r).add(u.User_Story__r);
                                                    }
                                                    else {
                                                        list<TKR_User_Story__c> newList = new list<TKR_User_Story__c>();
                                                        newList.add(u.User_Story__r);
                                                        designQuery.put(u.Design__r, newList);
                                                    }
                                                }
                
                for (TKR_Design__c D: designQuery.keyset()){
                    for (TKR_User_Story__c R : designQuery.get(D)){
                        US_With_Design.add(R.Id);
                    }
                }
                
                system.debug('Design Query ' +designQuery);
                system.debug('US with design ....' + US_With_Design);
                for (TKR_User_Story__c US:selectedUS){
                    if (!US_With_Design.contains(US.Id)){
                        US_NOT_DONE.add(US.Name);
                        str = str + US.Name + ' ,';
                    }
                }
            }
            system.debug('US NOT DONE ' + US_NOT_DONE);
            if(US_NOT_DONE.size()>0){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Warning, 'Please only select user stories which have a Design related to it.<br/> Below User Stories do not have a design: <br/>' + str + '<br/>'));
                return null;
            }
            else {
                if(Project_Name <> null && Project_Name != '--None--'){
                    system.debug('print the value of Project Id' + MapSelOps.get(Project_Name));
                    if(acc.isAuthorizedToView(oDefinitions, fieldsDefinitions) == true && acc.isAuthorizedToView(oProjects, fieldsProject) == true)
                    {
                        Definitions = [select id,Name,Project__c,Term_Acronym__c,Definition__c, Project__r.Name from TKR_Definitions__c where Project__c =: MapSelOps.get(Project_Name) WITH SECURITY_ENFORCED];   
                    }
                    if(Definitions.size()>0){
                        DefinitionsExist = true;
                    }
                    if(acc.isAuthorizedToView(oReferences, fieldsReferences) == true && acc.isAuthorizedToView(oProjects, fieldsProject) == true)
                    {
                        References  = [select id,Name,Document_ID__c,Project__c,Project__r.Name from TKR_References__c where Project__c =: MapSelOps.get(Project_Name) WITH SECURITY_ENFORCED];    
                    }
                    if(References.size()>0){
                        ReferencesExist =true;
                    }
                }  
                
                
                System.debug('Image:' + designQuery);
                System.Debug('SelectedUS: ' + selectedUS);
                system.Debug('References' + References);
                system.Debug('Definitions' + Definitions);
                System.Debug('idUS: ' + idUS);
                System.Debug('Design Query: ' + designQuery);
                
                // For Word Doc version determine the name of the file - Added 16/06/2015 M.Barber
                docName = 'Technical Design Document - ' + String.valueOf(Project_Name + Version); 
                PageReference p = Page.TechnicalDesignDocumentPDF;    
                return p;
            }
        }
        else {
            if(selectedUS.size()==0){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please select at least one User Story'));
            }
            if(Version == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Version'));
            }
            if(Organization == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter an Organization'));
            }
            if(Project_Name == '--None--'){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Project Name'));
            }
            return null;
        }
    }
    
    //FUNCTIONAL DOCUMENT    
    public pagereference CreateFunctionalDocument () {
        System.debug('in createfunctionaldocument');
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsEpic = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsDefinitions = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsProject = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsReferences = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsUserStory.add(TKR_User_Story__c.Name);
        fieldsUserStory.add(TKR_User_Story__c.As_A__c);
        fieldsUserStory.add(TKR_User_Story__c.As_A_Text__c);
        fieldsUserStory.add(TKR_User_Story__c.I_Want_To__c);
        fieldsUserStory.add(TKR_User_Story__c.So_that__c);
        fieldsUserStory.add(TKR_User_Story__c.Story_Points_Total__c);
        fieldsUserStory.add(TKR_User_Story__c.Development_Stage__c);
        fieldsUserStory.add(TKR_User_Story__c.Proposed_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Allocated_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Functional_Area__c);
        fieldsUserStory.add(TKR_User_Story__c.Sub_Process__c);
        fieldsUserStory.add(TKR_User_Story__c.QRCode__c);
        fieldsUserStory.add(TKR_User_Story__c.Acceptance_Criteria__c);
        fieldsUserStory.add(TKR_User_Story__c.Compliance_Criteria__c);
        
        fieldsEpic.add(TKR_Epic__c.Name);
        fieldsEpic.add(TKR_Epic__c.Epic_Details__c);
        
        fieldsDefinitions.add(TKR_Definitions__c.Name);
        fieldsDefinitions.add(TKR_Definitions__c.Project__c);
        fieldsDefinitions.add(TKR_Definitions__c.Term_Acronym__c);
        fieldsDefinitions.add(TKR_Definitions__c.Definition__c);
        
        fieldsProject.add(TKR_Project__c.Name);
        
        fieldsReferences.add(TKR_References__c.Name);
        fieldsReferences.add(TKR_References__c.Document_ID__c);
        fieldsReferences.add(TKR_References__c.Project__c);
        
        Schema.sObjectType oUserStory = TKR_User_Story__c.sObjectType;
        Schema.sObjectType oEpic = TKR_Epic__c.sObjectType;
        Schema.sObjectType oDefinitions = TKR_Definitions__c.sObjectType;
        Schema.sObjectType oProject = TKR_Project__c.sObjectType;
        Schema.sObjectType oReferences = TKR_References__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
        System.debug('### customFieldsOnUserStory : ' + customFieldsOnUserStory);
        
        Definitions = new List<TKR_Definitions__c>();
        References = new List<TKR_References__c>();
        Func_UserStory = new map<string,list<TKR_User_Story__c>> ();
        set<id> idUS = new set<id>();
        
        system.debug('in createfunctionaldocument 1' + ' version='+Version + ' org='+Organization + ' size='+selectedUS.size() +'  project name ='+Project_Name );
        if (Version != '' && Organization !='' && selectedUS.size()>0 && Project_Name != '--None--')
        {
            
            system.debug('in createfunctionaldocument 2');
            for(TKR_User_Story__c s: selectedUS) {
                idUS.add(s.id);
            }
            system.debug('---IdUS---'+ idUS);
            if(acc.isAuthorizedToView(oUserStory, fieldsUserStory) == true && acc.isAuthorizedToView(oEpic, fieldsEpic) == true)
            {
                String functionalQuery = 'SELECT Id,As_A__c,As_A_Text__c,I_Want_To__c, So_that__c,Name,Allocated_Sprint__r.Name, Functional_Area__c,Parent_Epic__r.name, Parent_Epic__r.Epic_Details__c, '
                                          + 'Sub_Process__c, Story_Points_Total__c, Developer__r.Name, Supporting_BA__r.Name, User__r.Name, QRCode__c '
                                          + (customFieldsOnUserStory.isEmpty() ? '' : (', ' + String.join(customFieldsOnUserStory, ','))) + ' FROM TKR_User_Story__c WHERE Id IN :idUS WITH SECURITY_ENFORCED Order By Name,Allocated_Sprint__r.Name,Functional_Area__c,Sub_Process__c';
                
                SObjectAccessDecision decisionSprint = Security.stripInaccessible(AccessType.READABLE,Database.query(functionalQuery));
                for(TKR_User_Story__c R: (List<TKR_User_Story__c>)decisionSprint.getRecords()) 
                {
                    if (!Func_UserStory.containsKey(R.Functional_Area__c))
                        Func_UserStory.put(R.Functional_Area__c,new list<TKR_User_Story__c>());
                    system.debug('+++++++++++++++' + R.As_A__c );
                    If (R.As_A__c != Null){
                        string temp = string.valueof(R.As_A__c);
                        R.As_A__c = temp.replace(';',',');
                        system.debug('+++++++++++++++' + R.As_A__c );
                    }
                    Func_UserStory.get(R.Functional_Area__c).add(R);
                }
            }
            system.debug('in createfunctionaldocument 3');               
            if(Project_Name <> null && Project_Name != '--None--'){
                
                if(acc.isAuthorizedToView(oDefinitions, fieldsDefinitions) == true && acc.isAuthorizedToView(oProject, fieldsProject) == true)
                {
                    Definitions = [select id,Name,Project__c,Term_Acronym__c,Definition__c, Project__r.Name from TKR_Definitions__c where Project__c =: MapSelOps.get(Project_Name) WITH SECURITY_ENFORCED];
                }                
                if(Definitions.size()>0){
                    DefinitionsExist = true;
                }
                if(acc.isAuthorizedToView(oReferences, fieldsReferences) == true && acc.isAuthorizedToView(oProject, fieldsProject) == true)
                {
                    References = [select id,Name,Document_ID__c,Project__c,Project__r.Name from TKR_References__c where Project__c =: MapSelOps.get(Project_Name) WITH SECURITY_ENFORCED];
                }
                
                if(References.size()>0){
                    ReferencesExist =true;
                }
            }
            // For Word Doc version determine the name of the file - Added 16/06/2015 M.Barber
            docName = 'Functional Design Document - ' + String.valueOf(Project_Name + Version);  
            system.debug('in createfunctionaldocument' +docName);
            
            Pagereference P = Page.FunctionalDocumentPDF;
            return p;
        }
        
        else 
        {
            if(selectedUS.size()==0){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please select at least one user story'));
            }
            if(Version == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Version'));
            }
            if(Organization == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter an Organization'));
            }
            if(Project_Name == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Project Name'));
            }
            return null;
        }
        
    }
    
    
    /* Commented CreateFunctionalDocumentWord() method as the functionality is ready for release yet.    
    //FUNCTIONAL DOCUMENT for WORD FORMAT
    public pagereference CreateFunctionalDocumentWord () {
        
        //Lists of objects which contains the fields for CRUD/FLS permission checks 
        List<Schema.SObjectField> fieldsUserStory = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsEpic = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsDefinitions = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsProject = new List<Schema.SObjectField>();
        List<Schema.SObjectField> fieldsReferences = new List<Schema.SObjectField>();
                        
        //Addition of the fields to the lists for which CRUD/FLS is to be checked for the logged in user
        fieldsUserStory.add(TKR_User_Story__c.Name);
        fieldsUserStory.add(TKR_User_Story__c.As_A__c);
        fieldsUserStory.add(TKR_User_Story__c.As_A_Text__c);
        fieldsUserStory.add(TKR_User_Story__c.I_Want_To__c);
        fieldsUserStory.add(TKR_User_Story__c.So_that__c);
        fieldsUserStory.add(TKR_User_Story__c.Story_Points_Total__c);
        fieldsUserStory.add(TKR_User_Story__c.Development_Stage__c);
        fieldsUserStory.add(TKR_User_Story__c.Proposed_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Allocated_Sprint__c);
        fieldsUserStory.add(TKR_User_Story__c.Functional_Area__c);
        fieldsUserStory.add(TKR_User_Story__c.Sub_Process__c);
        fieldsUserStory.add(TKR_User_Story__c.QRCode__c);
        fieldsUserStory.add(TKR_User_Story__c.Acceptance_Criteria__c);
        fieldsUserStory.add(TKR_User_Story__c.Compliance_Criteria__c);
        
        fieldsEpic.add(TKR_Epic__c.Name);
        fieldsEpic.add(TKR_Epic__c.Epic_Details__c);
        
        fieldsDefinitions.add(TKR_Definitions__c.Name);
        fieldsDefinitions.add(TKR_Definitions__c.Project__c);
        fieldsDefinitions.add(TKR_Definitions__c.Term_Acronym__c);
        fieldsDefinitions.add(TKR_Definitions__c.Definition__c);
        
        fieldsProject.add(TKR_Project__c.Name);
        
        fieldsReferences.add(TKR_References__c.Name);
        fieldsReferences.add(TKR_References__c.Document_ID__c);
        fieldsReferences.add(TKR_References__c.Project__c);
        
        Schema.sObjectType oUserStory = TKR_User_Story__c.sObjectType;
        Schema.sObjectType oEpic = TKR_Epic__c.sObjectType;
        Schema.sObjectType oDefinitions = TKR_Definitions__c.sObjectType;
        Schema.sObjectType oProject = TKR_Project__c.sObjectType;
        Schema.sObjectType oReferences = TKR_References__c.sObjectType;
                
        //Instantiating the ESAPI managed package class to check access controls
        SFDCAccessController acc = new SFDCAccessController();
        
        Definitions = new List<TKR_Definitions__c>();
        References = new List<TKR_References__c>();
        Func_UserStory = new map<string,list<TKR_User_Story__c>> ();
        set<id> idUS = new set<id>();
        if (Version != '' && Organization !='' && selectedUS.size()>0 && Project_Name != '--None--')
        {
            for(TKR_User_Story__c s: selectedUS) {
                idUS.add(s.id);
            }
            system.debug('---IdUS---'+ idUS);
            
            if(acc.isAuthorizedToView(oUserStory, fieldsUserStory) == true && acc.isAuthorizedToView(oEpic, fieldsEpic) == true)
            {
                for(TKR_User_Story__c R: [SELECT Id,As_A__c,I_Want_To__c, So_that__c,Name,Allocated_Sprint__r.Name, Functional_Area__c,Parent_Epic__r.name, Parent_Epic__r.Epic_Details__c,
                                          Sub_Process__c, Acceptance_Criteria__c, Compliance_Criteria__c, Story_Points_Total__c, Developer__r.Name, Supporting_BA__r.Name, User__r.Name, QRCode__c
                                          FROM TKR_User_Story__c
                                          WHERE Id IN :idUS Order By Name,Allocated_Sprint__r.Name,Functional_Area__c,Sub_Process__c]) 
                {
                    if (!Func_UserStory.containsKey(R.Functional_Area__c))
                        Func_UserStory.put(R.Functional_Area__c,new list<TKR_User_Story__c>());
                    system.debug('+++++++++++++++' + R.As_A__c );
                    If (R.As_A__c != Null){
                        string temp = string.valueof(R.As_A__c);
                        R.As_A__c = temp.replace(';',',');
                        system.debug('+++++++++++++++' + R.As_A__c );
                    }
                    Func_UserStory.get(R.Functional_Area__c).add(R);
                }
            }
            if(Project_Name <> null && Project_Name != '--None--'){
                if(acc.isAuthorizedToView(oDefinitions, fieldsDefinitions) == true && acc.isAuthorizedToView(oProject, fieldsProject) == true)
                {
                    Definitions = [select id,Name,Project__c,Term_Acronym__c,Definition__c, Project__r.Name from TKR_Definitions__c where Project__c =: MapSelOps.get(Project_Name)];
                }
                
                if(Definitions.size()>0){
                    DefinitionsExist = true;
                }
                if(acc.isAuthorizedToView(oReferences, fieldsReferences) == true && acc.isAuthorizedToView(oProject, fieldsProject) == true)
                {
                    References = [select id,Name,Document_ID__c,Project__c,Project__r.Name from TKR_References__c where Project__c =: MapSelOps.get(Project_Name)]; 
                }
                
                if(References.size()>0){
                    ReferencesExist =true;
                }
            }
            // For Word Doc version determine the name of the file - Added 16/06/2015 M.Barber
            docName = 'Functional Design Document - ' + String.valueOf(Project_Name + Version);  
            
            Pagereference P = Page.FunctionalDocumentWord;
            return p;
        }
        
        else 
        {
            if(selectedUS.size()==0){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please select at least one user story'));
            }
            if(Version == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Version'));
            }
            if(Organization == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter an Organization'));
            }
            if(Project_Name == ''){
                ApexPages.addmessage(new ApexPages.message(ApexPages.severity.WARNING,'Please enter a Project Name'));
            }
            return null;
        }
        
    }
    */
    
    
    
    // QR CARD DOCUMENT
    public pagereference generateQAcards(){
        PageReference np = new PageReference('/apex/TKR_GenerateCard');
        np.setRedirect(false);
        return np;
        
    }
    
    
    
    public string domainName {
        get{
            if(domainName ==null){
                try{
                    //set the site domain url value
                    TKR_Domain_URL__c domName = TKR_Domain_URL__c.getOrgDefaults();
                    String dUrl = domName.URL__c;  
                    
                    // Check custom setting whether to use custom or standard QR Code URL
                    Boolean QRCode_URL = TKR_QR_Code_URL__c.getInstance().Enable_Custom_QR_Code_Page__c;
                    
                    if (QRCode_URL ==true)
                        {                 
                        // Custom QR Code Image
                        return 'https://chart.googleapis.com/chart?chf=bg,s,ffffff&cht=qr&chs=150x150&chl=https://'+dUrl+'/QRScan?id=';
                        }
                    Else
                        {
                        // Standard mobile QR Code Image
                        return 'https://chart.googleapis.com/chart?chf=bg,s,ffffff&cht=qr&chs=150x150&chl=https://'+dUrl+'/';
                        
                        }
                }catch (exception e){
                    return null;
                }
            }
            else
                return null;            
        }
        private set{
        }
    }
    //sph 26.08.2015 select document type
    public pagereference SelectFunctionalDocumentType(){return null;}
    
    /************** for popup ******************/
    
    
    public boolean displayOLIPopup {get; set;}
    public boolean displayPopup {get; set;}
    
    public Pagereference selectPDFPopup() {
        
        displayOLIPopup = false;           
        // try to refresh vf page
        // if version
        PageReference pageRef = createFunctionalDocument();//new PageReference('/apex/'+PricingScreenPageName+'?opid='+opid); 
        //pageRef.setRedirect(true);   
        return pageRef;            
        
    } 
    public void selectDocPopup() {
        
        displayOLIPopup = false;     
        // try to refresh vf page
        //PageReference pageRef = null;//new PageReference('/apex/'+PricingScreenPageName+'?opid='+opid); 
        //pageRef.setRedirect(true);   
        //return pageRef;            
        
    } 
    public void closePopup() {
        displayOLIPopup = false;// cancel without saving
    }
    
    
    public void showOLIPopup() {
        displayOLIPopup = true;
        //  displayOLIPopup2 = false;
    }   
}