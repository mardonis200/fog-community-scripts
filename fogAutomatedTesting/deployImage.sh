#!/bin/bash

cwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$cwd/settings.sh"

# First argument is our vmname
vmname="$1"
# Second argument is the ID
fogid="$2"

# Ask for the VM guest name.
if [[ -z $vmname ]]; then
    echo "$(date +%x_%r) No vmGuest name passed for argument 1, exiting." >> $output
    exit
else
    vmGuest=$vmname
fi

# Ask for the FOG ID of the guest we are to use for deploy.
if [[ -z $fogid ]]; then
    echo "$(date +%x_%r) No vmGuestFogID passed for argument 2, exiting." >> $output
    exit
else
    vmGuestFogID=$fogid
fi

echo "$(date +%x_%r) Queuing deploy. vmGuest=\"${vmGuest}\" vmGuestFogID=\"${vmGuestFogID}"\" >> $output

# Headers
contenttype="-H 'Content-Type: application/json'"
usertoken="-H 'fog-user-token: ${testServerUserToken}'"
apitoken="-H 'fog-api-token: ${testServerApiToken}'"

# Body to send
body="'{\"taskTypeID\":1}'"

# URL to call
url="http://${testServerIP}/fog/host/${vmGuestFogID}/task"

# Queue the deploy jobs with the test fog server.
cmd="curl --silent -k ${contenttype} ${usertoken} ${apitoken} ${url} -d ${body}"
eval $cmd >/dev/null 2>&1 # Don't care that it says null.

sleep 5

# Reset the VM forcefully.
echo "$(date +%x_%r) Resetting \"${vmGuest}\" to begin deploy." >> ${output}
ssh -o ConnectTimeout=${sshTimeout} ${hostsystem} "virsh start \"${vmGuest}\"" >/dev/null 2>&1


count=0
#Need to monitor task progress somehow. Once done, should exit.
getStatus="${cwd}/getTaskStatus.sh ${vmGuestFogID}"
while [[ ! $count -gt $deployLimit ]]; do
    status=$($getStatus)
    if [[ $status -eq 0 ]]; then
        echo "$(date +%x_%r) Completed image deployment to \"${vmGuest}\" in about \"${count}\" minutes." >> ${output}
        echo "Completed image deployment to \"${vmGuest}\" in about \"${count}\" minutes." >> ${report}
        break
    fi
    let count+=1
    sleep 60
done
if [[ $count -gt $deployLimit ]]; then
    echo "$(date +%x_%r) Image Capture did not complete within ${deployLimit} seconds." >> ${output}
    echo "Image Capture did not complete within ${deployLimit} minutes." >> ${report}
fi
nonsense=$(timeout ${sshTime} ssh -o ConnectTimeout=${sshTimeout} ${hostsystem} "echo wakeup")
nonsense=$(timeout ${sshTime} ssh -o ConnectTimeout=${sshTimeout} ${hostsystem} "echo get ready")
sleep 5
ssh -o ConnectTimeout=${sshTimeout} ${hostsystem} "virsh destroy \"${vmGuest}\"" >/dev/null 2>&1
