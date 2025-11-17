# griffler
## an application to deploy a webapp and test it
this application will use kubernetes, aws and github actions to deploy three services:
- griffler - a static instance
  - dashboard with information about test runs
    - urls for the various services
    - artifacts such as screenshots
    - information about the PR that was merged
    - performance test results
    - rollback button to deploy the previous commit, before the PR
  - db of test runs
  - api
- testapp - a webapp to be tested
  - webpage - should have a number of elements that can be tested, text boxes, dropdowns, etc to be tested with playwright
  - api - to be tested with playwright REST integration tests
- test cluster - the master tester that runs the tests
  - playwrite (UI / API)
  - locust.io (performance)
  - writes to griffler db once tests are complete

## the steps (Actions):
- spin up griffler
- on pr creation >
- pull and deploy testapp @ PR
- pull and deploy testcluster
- deploy tester nodes
- run tests against webapp
- publish test results to griffler/db
- on pr merge >
- tear down everything except griffler
