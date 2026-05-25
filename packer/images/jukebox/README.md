# Bake image

Provisions a VM of the specified flavor (temporarly), runs an Ansible playbook to configure it, then snapshots the 
result into a reusable machine image.

./build.sh dev us-east-1 nvidia

# Run a test instance

./test.sh dev us-east-1 nvidia
