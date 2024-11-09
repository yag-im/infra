# grafana integration

http://prometheus-operated.otel:9090
http://loki-gateway.otel

# pull docker images (run on jukeboxsvc node)

    curl -v --request POST \
        --url http://localhost:80/cluster/pull_image \
        --header 'content-type: application/json' \
        --header 'user-agent: vscode-restclient' \
        --data '{"repository": "070143334704.dkr.ecr.us-east-1.amazonaws.com/im.acme.yag.jukebox","tag": "x11_gpu-intel_scummvm_2.8.1_latest"}'

Or directly on the node:

    AWS_PROFILE=ecr-ro docker pull 070143334704.dkr.ecr.us-east-1.amazonaws.com/im.acme.yag.jukebox:x11_gpu-intel_scummvm_2.8.1_latest

FAQ

Q: Error:
[jukeboxsvc] [ERROR] {"code": 1500, "message": "error while creating mount source path '/mnt/appstor/1/ripper/1ecc1775-d909-4c50-96db-d54062e17b00': chown /mnt/appstor/1/ripper/1ecc1775-d909-4c50-96db-d54062e17b00: operation not permitted"}
on container run.

A: Happens when removing cloned folder direclty from the jukebox node, e.g.:

    debian@jukebox1:~$ rm -rf /mnt/appstor/1/ripper

and then trying to run the game from web.

You should always delete files from appstor node itself.


Q: System cursor is visible no matter what
A: Check show-pointer of ximagesrc in streamd


Q: Stream is too slow, lot of packets losses, errors like:

    0:00:31.174352245    90 0x7f27c46f10c0 WARN              rtprtxsend gstrtprtxsend.c:814:gst_rtp_rtx_send_src_event:<rtprtxsend0> requested seqnum 65529 has not been transmitted yet in the original stream; either the remote end is not configured correctly, or the source is too slow

appear in the jukebox docker logs

A: restart browser. Yep, sometimes google chrome starts to throttle with no reason.

Q: What are some useful certs commands

A:

Get all certificates:

    kubectl get certificates -n istio-gw-public -o yaml

Get cert pods:

    kubectl get pods -n cert-manager

Renewal logs:

    kubectl logs -n cert-manager cert-manager-796cbd6574-sqs77

Manual renew:

    cd /tmp
    curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64
    cd /workspaces/infra/tofu/envs/prod
    /tmp/cmctl inspect secret yag-im-tls -n istio-gw-public
    /tmp/cmctl status certificate yag-im-tls -n istio-gw-public
    /tmp/cmctl renew yag-im-tls -n istio-gw-public

TODO:

Autorefresh, spins-up some instances which are not able to update certs, need to investigate this.
