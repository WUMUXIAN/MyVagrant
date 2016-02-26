## This fire up a VM that has fluentd installed which tails a file and streaming to S3 bucket every 1 hour.

###HOW TO USE
vagrant up

### Minimum Requirement of configuration
Open td-agent.conf.j2 and modifiy your AWS credentials and S3 settings (<b>be caredful to not expose these!!</b>):
- aws_key_id
- aws_sec_key
- s3_region
- s3_bucket

### You can also modify the td-agent.conf.j2 to do what you want if you know fluentd well.
