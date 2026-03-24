#!/bin/bash
set -e

cd /Users/dino/Documents/AZURE

REPO="my_first_ee"
if [ ! -d "$REPO" ]; then
  mkdir my_first_ee
fi

cd my_first_ee

ENV_FILE="execution-environment.yml"
IMAGE_NAME="postgresql_ee"

if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" << 'EOF'
version: 3

images:
  base_image:
    name: registry.fedoraproject.org/fedora:42

dependencies:
  python_interpreter:
    package_system: python3
  ansible_core:
    package_pip: ansible-core
  ansible_runner:
    package_pip: ansible-runner
  system:
  - openssh-clients
  - sshpass
  galaxy:
    collections:
    - name: community.postgresql
EOF

  ansible-builder build --tag postgresql_ee
  if [ -f context/Dockerfile ]; then
    printf "creation succeed\n"
  else
    printf "error no dockerfile created\n"
    exit 1
  fi
  if ansible-navigator images --mode stdout | grep -q "$IMAGE_NAME"; then
    printf "build has succeed\n"
  else
    printf "build has failed\n"
    exit 1
  fi
fi

TEST_LOCALHOST="test_localhost.yml"

if [ ! -f "$TEST_LOCALHOST" ]; then
  cat > "$TEST_LOCALHOST" << 'EOF'
- name: Gather and print local facts
  hosts: localhost
  become: true
  gather_facts: true
  tasks:

   - name: Print facts
     ansible.builtin.debug:
      var: ansible_facts
EOF
  INVENTORY="inventory.yml"

  # Crée l'inventory AVANT le playbook
  if [ ! -f "$INVENTORY" ]; then
    cat > "$INVENTORY" << 'EOF'
all:
  hosts:
    localhost:
      ansible_connection: local
EOF
  fi
  # AJOUTE -i inventory.yml CRUCIAL !
  output=$(ansible-navigator run "$TEST_LOCALHOST" \
    -i "$INVENTORY" \
    --execution-environment-image "$IMAGE_NAME" \
    --container-options='--user=0' \
    --pull-policy missing \
    --mode stdout)

  if [ $? -eq 0 ]; then
    printf "✅ Playbook run succeeded\n"
    printf "%s\n" "$output"
  else
    printf "❌ Playbook run failed\n"
    printf "%s\n" "$output"
    exit 1
  fi
fi
