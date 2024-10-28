#!/usr/bin/env bash

USERNAME=infra

mkdir -p /home/$USERNAME/.ssh
printf '%s\n' "$AUTHORIZED_KEYS" > /home/$USERNAME/.ssh/authorized_keys
printf '%s\n' "$ED25519_KEY_PUB" > /home/$USERNAME/.ssh/id_ed25519.pub
printf '%s\n' "$ED25519_KEY" > /home/$USERNAME/.ssh/id_ed25519
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/id_ed25519.pub
chmod 600 /home/$USERNAME/.ssh/id_ed25519
chown -R $USERNAME /home/$USERNAME/.ssh

/usr/sbin/sshd -D
# /usr/sbin/sshd -D -e -ddd
