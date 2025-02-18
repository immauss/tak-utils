A docker-compose.yaml and needed files to create a TAK server. 

This setup makes the inital setup of the TAK server easier by automating the setup steps. 

It also provides persistence of certs and database through docker volumes.
For more info on the TAK server see:
- https://civtag.org
- https://tak.gov

# Setup
1. Edit the docker-compose.yaml and give appropriate values for the Environement variables.
   - STATE
   - CITY
   - ORGANIZATION
   - ORGANIZATION_UNIT
   - envpass     ( This one is on both containers, though I'm not sure it needs to be on both.)
3. Edit the CoreConfig.xml and set the password. It should match the password given in the compose file.
4. run ``` docker-compose up -d```
5. Wait paitently. The first run waits for about 3 minutes before it loads the admin cert and then restarts the container. After that, it should be accessible. 
