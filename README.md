# griffler
## an application to deploy a webapp and test it
this application will use kubernetes, aws and --- to deploy three services:
- griffler - a static instance
  - dashboard
  - db
  - api
- testapp - a webapp to be tested
  - wepage
  - api
- test cluster - the master tester that runs the tests
  - playwrite (UI / API)
  - locust.io (performance)

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
