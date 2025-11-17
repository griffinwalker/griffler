# griffler
## an application to deploy a webapp and test it
this application will use kubernetes, aws and github actions to deploy three services:
- griffler - a static instance
  - dashboard with information about test runs
    - urls for the various services
    - artifacts such as screenshots
    - information about the PR that was merged
    - performance test results
    - option to deploy previous testapp versions
    - rollback button to deploy the previous commit, before the PR
  - db of test runs
  - api
- testapp-staging - a webapp to be tested of the PR 
  - webpage - should have a number of elements that can be tested with playwright UI tests eg:  text input boxes, dropdown menu, hamburger menu, links etc
  - api - to be tested with playwright REST integration tests
- test cluster - the master tester that runs the tests
  - playwrite (UI / API)
  - locust.io (performance)
  - writes to griffler db once tests are complete

## the steps (Actions):
- spin up griffler
- on pr creation >
- pull testapp repo @ PR and deploy to testapp-staging
- pull and deploy testcluster using eks
- deploy tester nodes using eks
- run plawrite tests against testapp-staging
- run performace tests (locust.io) against testapp-staging
- publish test results to griffler/db
- on pr merge > deploy testapp:master to new s3bucket testapp-prod
- tear down everything except griffler and testapp-prod
