/*******************************************************************************
* @author       Jericson Mercado
* @date         2020-02-23
* @description  Base class for Continuous Integration
*******************************************************************************/
public without sharing virtual class TKR_CIBase { // CRUD/Sharing False Positive: the class is a base class which handles the continuous integration regardless of user permissions 

    public static Set<Id> usIdsInProcess = new Set<Id>(); // this contains all the user stories being process (solution to recursive trigger due to workflow field update)

    public class NotImplementedException extends Exception {}

    // user story and ci configuration
    public USWrapper userStory;
    public TKR_CISetting__c ciSetting;

    // fixed reference
    public String FEATURE = 'feature';
    public String RELEASE = 'release';

    // request parameters
    public String endpoint;
    public String method;
    public String parameters;

    // response
    public ResponseWrap response;

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that sends the request to 3rd party
    * @param
    * @return
    *******************************************************************************/
    public void sendRequest(){
        HttpRequest request = new HttpRequest();
        response = new ResponseWrap();
        HttpResponse res = new HttpResponse();

        try{
            request.setHeader('Content-Type', 'application/json');
            request.setEndpoint('callout:' + ciSetting.TKR_Named_Credential__c + '/' + endpoint);
            request.setMethod(method);

            if(String.isNotBlank(parameters))
                request.setBody(parameters);

            res = new Http().send(request);
        }
        catch(CalloutException ex) {
            system.debug(ex.getMessage());
        }

        response.statusCode = res.getStatusCode();
        response.body = res.getBody();
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method calls the prepopulation of the endpoint, method and parameter to be sent when creating branch
    * @param
    * @return
    *******************************************************************************/
    public ResponseWrap createNewBranch(String sourceBranch, String parentBranchId){
        parameters = '';
        setCreateBranchParameter(sourceBranch, parentBranchId);
        sendRequest();
        processCreateBranchResponse(sourceBranch);
        return response;
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method calls the prepopulation of the endpoint, method and parameter to be sent when creating pull request
    * @param
    * @return
    *******************************************************************************/
    public ResponseWrap createPullRequest(){
        parameters = '';
        setPullRequestParameter();
        sendRequest();
        processPullRequestResponse();
        return response;
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that will be overriden on how getting the branch ID will be handled, this will be different per source (bitbucket/github)
    * @param
    *               branchType [String] - specifies if feature or release branch will be used
    * @return
    *******************************************************************************/
    public virtual ResponseWrap getBranchId(String branchName){
        throw new NotImplementedException('getBranchId ' + Label.TKR_CI_Method_not_yet_implemented);
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that will be overriden on how sending the parameter for creating branch will be handled,
                    this will be different per source (bitbucket/github)
    * @param
    *               branchType [String] - specifies if feature or release branch will be used
    * @return
    *******************************************************************************/
    public virtual void setCreateBranchParameter(String sourceBranch, String parentBranchId) {
        throw new NotImplementedException('setCreateBranchParameter ' + Label.TKR_CI_Method_not_yet_implemented);
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that will be overriden on how sending the parameter for creating pull request will be handled,
                    this will be different per source (bitbucket/github)
    * @param
    * @return
    *******************************************************************************/
    public virtual void setPullRequestParameter() {
        throw new NotImplementedException('setPullRequestParameter ' + Label.TKR_CI_Method_not_yet_implemented);
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that will be overriden per SCM what to do after creating branch
    * @param
    * @return
    *******************************************************************************/
    public virtual void processCreateBranchResponse(String sourceBranch){}

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  method that will be overriden per SCM what to do after creating branch
    * @param
    * @return
    *******************************************************************************/
    public virtual void processPullRequestResponse(){}

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-23
    * @description  method to get the configuration of the project
    * @param
                    projectIds [Set of Id] - set of project Ids
    * @return       map of TKR_CISetting__c with project as the key Id
    *******************************************************************************/
    public static Map<String, TKR_CISetting__c> getProjectConfiguration(Set<String> projectIds, Map<String, String> sprintProjectMap){
        Map<String, TKR_CISetting__c> tempMap1 = new Map<String, TKR_CISetting__c>();
        Map<String, TKR_CISetting__c> tempMap2 = new Map<String, TKR_CISetting__c>();

        Set<Id> ciSettingIds = new Set<Id>();
        List<TKR_Project__c> projectList = new List<TKR_Project__c>( [SELECT TKR_CI_Configuration__c
                                                                        FROM TKR_Project__c
                                                                    WHERE Id IN: projectIds]);
        // Strip fields that are not readable
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE,projectList);
        for(TKR_Project__c project: (List<TKR_Project__c>) decision.getRecords()){
            ciSettingIds.add(project.TKR_CI_Configuration__c);
        }
        // Strip fields that are not readable
        SObjectAccessDecision decisionCiSetting = Security.stripInaccessible(AccessType.READABLE,[SELECT TKR_isActive__c,
        TKR_Branching_Strategy__c,
        TKR_Feature_Branch_Prefix_Name__c,
        TKR_Feature_Branch_Source__c,
        TKR_Branch_Creation_User_Story_Status__c,
        TKR_Named_Credential__c,
        TKR_Owner_Username__c,
        TKR_OrgWide_Default__c,
        TKR_Release_Branch_Prefix_Name__c,
        TKR_Release_Branch_Source__c,
        TKR_Pull_Request_User_Story_Status__c,
        TKR_Repository_Name__c,
        TKR_Repository_Type__c,
        TKR_Workspace_Name__c
      FROM TKR_CISetting__c
     WHERE Id IN: ciSettingIds
           OR TKR_OrgWide_Default__c = TRUE]);
        // get CI needed per project get only Feature and DROP
        for(TKR_CISetting__c ci: (List<TKR_CISetting__c>)decisionCiSetting.getRecords()){
            
            // check if project has CI Configured
            if(ci.TKR_isActive__c
                && ci.TKR_OrgWide_Default__c){
                tempMap1.put('DEFAULT', ci);
                tempMap2.put('DEFAULT', ci);
            }
            tempMap1.put(ci.Id, ci);
        }

        // loop per project
        for(TKR_Project__c project: projectList){
            if(project.TKR_CI_Configuration__c != null){
                tempMap2.put(project.Id, tempMap1.get(project.TKR_CI_Configuration__c));
            }
        }
        // loop per sprint
         // Strip fields that are not readable
         SObjectAccessDecision decisionSprint = Security.stripInaccessible(AccessType.READABLE,[SELECT TKR_Feature_Branch_Source__c, TKR_Feature_Branch_Prefix_Name__c,
         TKR_Release_Branch_Source__c, TKR_Release_Branch_Prefix_Name__c,
         Project__c
    FROM TKR_Sprint__c
   WHERE Id IN: sprintProjectMap.KeySet()]);
        for(TKR_Sprint__c sprint: (List<TKR_Sprint__c>)decisionSprint.getRecords()){
            TKR_CISetting__c ci;
            // get org wide default
            if(tempMap2.containsKey('DEFAULT'))
                ci = tempMap2.get('DEFAULT').clone();

            // override with the project level
            if(tempMap2.containsKey(sprint.Project__c))
                ci = tempMap2.get(sprint.Project__c).clone();

            // check for an override
            if(ci != null) {
                if(String.isNotBlank(sprint.TKR_Feature_Branch_Source__c))
                    ci.TKR_Feature_Branch_Source__c = sprint.TKR_Feature_Branch_Source__c;
                if(String.isNotBlank(sprint.TKR_Feature_Branch_Prefix_Name__c))
                    ci.TKR_Feature_Branch_Prefix_Name__c = sprint.TKR_Feature_Branch_Prefix_Name__c;
                if(String.isNotBlank(sprint.TKR_Release_Branch_Source__c))
                    ci.TKR_Release_Branch_Source__c = sprint.TKR_Release_Branch_Source__c;
                if(String.isNotBlank(sprint.TKR_Release_Branch_Prefix_Name__c))
                    ci.TKR_Release_Branch_Prefix_Name__c = sprint.TKR_Release_Branch_Prefix_Name__c;
                tempMap2.put(sprint.Id, ci);
            }
        }
        return tempMap2;
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-03-01
    * @description  method to get the access authorized to the user
    * @param
    * @return       Set of named credentials available for the user to use
    *******************************************************************************/
    public static Set<String> getUserNamedCredential(){
        Set<Id> namedCredentialIds = new Set<Id>();
		Id sUserId = UserInfo.getUserId();
        // Strip fields that are not readable
        SObjectAccessDecision decisionExtneralData = Security.stripInaccessible(AccessType.READABLE,[SELECT ExternalDataSourceId FROM ExternalDataUserAuth WHERE UserId =: sUserId]);
        for(ExternalDataUserAuth userAuth: (List<ExternalDataUserAuth>)decisionExtneralData.getRecords()){
            namedCredentialIds.add(userAuth.ExternalDataSourceId);
        }
        Set<String> userAccess = new Set<String>();
         // Strip fields that are not readable
         SObjectAccessDecision decisionNamedCred = Security.stripInaccessible(AccessType.READABLE,[SELECT DeveloperName FROM NamedCredential WHERE Id IN: namedCredentialIds]);
         for(NamedCredential nc: (List<NamedCredential>)decisionNamedCred.getRecords()){
            userAccess.add(nc.DeveloperName);
        }

        // manually add to mock NamedCredential and ExternalDataUserAuth in test class
        if(Test.isRunningTest()){
            userAccess = new Set<String>{'Bitbucket', 'Github','fail'};
        }

        return userAccess;
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-03-03
    * @description  method to get named credentials of the CI
    * @param
    * @return       Set of named credentials available for the user to use
    *******************************************************************************/
    public static Set<String> getCICredentials(){
        Set<String> ciCreds = new Set<String>();
          // Strip fields that are not readable
          SObjectAccessDecision decisionCiSetting = Security.stripInaccessible(AccessType.READABLE,[SELECT TKR_Named_Credential__c
          FROM TKR_CISetting__c
         WHERE TKR_isActive__c = true]);
       
        for(TKR_CISetting__c ci: (List<TKR_CISetting__c>)decisionCiSetting.getRecords()){
            ciCreds.add(ci.TKR_Named_Credential__c);
        }
        return ciCreds;
    }

    /*******************************************************************************
    * @author       Robbie Macatbag
    * @date         2020-02-09
    * @description  apex method to create chatter feeds and with @mention.
    * @param
                    statusMessage [String] - text body of feed
                    subjectId  [String] - salesforceID of the subject (parentid)
    * @return       N/A
    *******************************************************************************/
    public void createFeedItemMentionUser(String statusMessage, String subjectId){
        ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
        ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
        ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
        ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();

        messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
        mentionSegmentInput.id = UserInfo.getUserId();
        messageBodyInput.messageSegments.add(mentionSegmentInput);

        textSegmentInput.text = ' '+statusMessage;
        messageBodyInput.messageSegments.add(textSegmentInput);

        feedItemInput.body = messageBodyInput;
        feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
        feedItemInput.subjectId = subjectId;

        // ConnectApi not accessible in test class
        if(!Test.isRunningTest()) ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  Wrapper class to contain Userstory details
    *******************************************************************************/
    public class USWrapper {
        public String xId {get;set;}
        public String xName {get;set;}
        public String projectId {get;set;}
        public String proposedSprintId {get;set;}
        public String allocatedSprintId {get;set;}
        public String previousStatus {get;set;}
    }

    /*******************************************************************************
    * @author       Jericson Mercado
    * @date         2020-02-22
    * @description  Wrapper class to contain response
    *******************************************************************************/
    public class ResponseWrap {
        public Boolean isSuccess {get;set;}
        public Integer statusCode {get;set;}
        public String body {get;set;}
        public String branchId {get;set;}
    }
}