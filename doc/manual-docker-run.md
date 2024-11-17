# manual docker run

## dev

### gpu-intel

    docker run \
        -it \
        --rm \
        --name=jukebox_0_tester \
        --network=host \
        -e FPS='60' \
        -e MAX_INACTIVITY_PERIOD='1800' \
        -e SIGNALER_AUTH_TOKEN='Yx8e4L90' \
        -e SIGNALER_HOST='dev.yag.im' \
        -e SIGNALER_URI='wss://dev.yag.im/webrtc' \
        -e SCREEN_HEIGHT='480' \
        -e SCREEN_WIDTH='640' \
        -e STUN_URI='stun://stun.l.google.com:19302' \
        -e WS_CONN_ID='ac01272c-8796-43b4-84f2-79fe7fe7179c' \
        -e WS_CONSUMER_ID='22a7ba94-8e42-401b-a24b-4b941923c08b' \
        -e DISPLAY=':23444' \
        -e SHOW_POINTER=false \
        --device=/dev/dri/renderD128 \
        --device=/dev/dri/card0 \
        --device=/dev/snd/seq \
        --shm-size="2g" \
        --mount type=volume,source=appstor-vol,target=/opt/yag,volume-subpath=0/bad-mojo/018a9877-1ae1-45b4-a04f-0098a4ceb73f \
        ghcr.io/yag-im/jukebox/x11_gpu-intel_dosbox-x_2024.03.01:latest

### cpu

    docker run \
        -it \
        --rm \
        --name=jukebox_0_the-black-mirror_5dc73b7f \
        --network=host \
        -e FPS='60' \
        -e MAX_INACTIVITY_PERIOD='1800' \
        -e SIGNALER_AUTH_TOKEN='Yx8e4L90' \
        -e SIGNALER_HOST='dev.yag.im' \
        -e SIGNALER_URI='wss://dev.yag.im/webrtc' \
        -e SCREEN_HEIGHT='600' \
        -e SCREEN_WIDTH='800' \
        -e STUN_URI='stun://stun.l.google.com:19302' \
        -e WS_CONN_ID='ac01272c-8796-43b4-84f2-79fe7fe7179c' \
        -e WS_CONSUMER_ID='22a7ba94-8e42-401b-a24b-4b941923c08b' \
        -e DISPLAY=':23444' \
        -e SHOW_POINTER=false \
        --device=/dev/snd/seq \
        --shm-size="2g" \
        --mount type=volume,source=appstor-vol,target=/opt/yag,volume-subpath=0/the-black-mirror/1596ac0f-47e5-4a97-98bc-528e204fc694 \
        ghcr.io/yag-im/jukebox/x11_cpu_wine_9.0:latest

## local host run

### gpu-intel

    docker run \
        -it \
        --rm \
        --name=jukebox_0_test \
        --network=host \
        -e FPS='60' \
        -e MAX_INACTIVITY_PERIOD='1800' \
        -e SIGNALER_AUTH_TOKEN='Yx8e4L90' \
        -e SIGNALER_HOST='yag.dc' \
        -e SIGNALER_URI='ws://0.0.0.0:8081/webrtc' \
        -e SCREEN_HEIGHT='480' \
        -e SCREEN_WIDTH='640' \
        -e STUN_URI='stun://stun.l.google.com:19302' \
        -e WS_CONN_ID='ac01272c-8796-43b4-84f2-79fe7fe7179c' \
        -e WS_CONSUMER_ID='062bfea5-4029-496d-a565-eb5f070bc1aa' \
        -e DISPLAY=':23444' \
        -e SHOW_POINTER=false \
        --device=/dev/dri/renderD128 \
        --device=/dev/dri/card0 \
        --device=/dev/snd/seq \
        --shm-size="2g" \
        --mount type=volume,source=appstor-vol,target=/opt/yag,volume-subpath=0/the-prince-and-the-coward/02959ab5-aefb-44a1-b2ca-4fe5cd515f04 \
        x11_gpu-intel_wine_9.0:latest

### cpu

    docker run \
        -it \
        --rm \
        --name=jukebox_0_versailles-1685_fbe1b341 \
        --network=host \
        -e FPS='60' \
        -e MAX_INACTIVITY_PERIOD='1800' \
        -e SIGNALER_AUTH_TOKEN='Yx8e4L90' \
        -e SIGNALER_HOST='yag.dc' \
        -e SIGNALER_URI='ws://0.0.0.0:8081/webrtc' \
        -e SCREEN_HEIGHT='480' \
        -e SCREEN_WIDTH='640' \
        -e STUN_URI='stun://stun.l.google.com:19302' \
        -e WS_CONN_ID='ac01272c-8796-43b4-84f2-79fe7fe7179c' \
        -e WS_CONSUMER_ID='709e6029-cf8d-4d94-b87c-15187df3e6bb' \
        -e DISPLAY=':23444' \
        -e SHOW_POINTER=false \
        --device=/dev/snd/seq \
        --shm-size="2g" \
        --mount type=volume,source=appstor-vol,target=/opt/yag,volume-subpath=0/versailles-1685/46ba41a8-6a36-45f9-a594-278c2e2d0af0 \
        x11_cpu_scummvm_2.8.1:latest
