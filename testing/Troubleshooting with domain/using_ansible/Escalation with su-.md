# Нормальная схема здесь — ключ кладётся в локальную техническую учётку, а привилегии поднимаются через su - уже внутри Ansible.
## С клиентской машины сначала собираем список машин из домена через DNS/LDAP/Samba-инструменты. 
## Потом превращаем его в inventory.ini, потом Ansible заходит на машины по SSH под локальной учёткой с паролем, поднимается через su - до root и раскладывает ключи, sshd_config и дальше уже работает штатно.
# Важный момент: я бы не включал SSH-вход под root. 
## Это плохая практика и потом безопасники справедливо прицепятся(нет). 
## Лучше: localadmin или другая локальная техническая учётка, вход по ключу, затем su - до root для административных действий.

---

## Сначала поставь на управляющей машине нужные пакеты. Названия могут слегка отличаться, но общий набор такой:

```bash
su -

apt-get update
apt-get install -y ansible openssh-clients sshpass openldap-clients samba-client bind-utils
```

Если bind-utils в ALT называется иначе, проверь:

```bash
apt-cache search nslookup
apt-cache search bind-utils
```
### Теперь первый скрипт: получить список компьютеров из Active Directory через LDAP. 
### Даже если у вас «LDAP никакого нет», у Active Directory LDAP как протокол обычно есть на самих контроллерах домена: порт 389 для LDAP и 636 для LDAPS. 
### Отдельный LDAP-сервер не нужен. 
### Скрипт делает Kerberos-вариант через текущий билет, то есть сначала желательно выполнить:
```bash
kinit доменный_пользователь
```

## Сбор списка машин - discover-ad-computers-ldap.sh
Запуск:
```bash
chmod +x discover-ad-computers-ldap.sh

kinit DOMAIN_USER
./discover-ad-computers-ldap.sh domain.controller.address 'DC=nw,DC=controller,DC=ru' domain-hosts.txt
```

### Если Kerberos не взлетит, можно сделать вариант с логином и паролем. Он менее красивый, зато часто проще.
discover-ad-computers-ldap-simple.sh:
```bash
chmod +x discover-ad-computers-ldap-simple.sh

./discover-ad-computers-ldap-simple.sh \
  domain.controller.address \
  'DOMAIN\username' \
  'DC=nw,DC=controller,DC=ru' \
  domain-hosts.txt
```
### Если LDAP-запросы запрещены или режутся, можно собрать хосты грубее через DNS. Это хуже, потому что DNS-зона может содержать мусор, старые записи и не только рабочие станции, но как запасной вариант годится. 
discover-hosts-dns-zone.sh:
```bash

```
### Но не удивляйся, если AXFR запрещён. В нормальной сети он должен быть запрещён для обычных клиентов.
### Теперь скрипт, который из списка FQDN делает Ansible inventory. 
make-ansible-inventory.sh:
```bash
chmod +x make-ansible-inventory.sh
./make-ansible-inventory.sh domain-hosts.txt inventory.ini localadmin
```
### Теперь подготовка SSH-ключа на управляющей машине:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_alt_ed25519 -C "ansible-alt-admin"
```

Далее плейбук, который зайдёт по паролю под локальной учёткой, поднимется через su -, создаст .ssh, положит публичный ключ и настроит sshd_config. 
Можно было бы не делать замену всего sshd_config, а drop-in-конфиг, если версия OpenSSH его поддерживает через Include /etc/openssh/sshd_config.d/*.conf или /etc/ssh/sshd_config.d/*.conf. 
Но на ALT может быть своя раскладка. Поэтому плейбук сначала определяет, где лежит конфиг.

Структура:
```
ansible-alt-bootstrap/
├── inventory.ini
├── bootstrap-ssh.yml
├── files/
│   └── ansible_alt_ed25519.pub
└── templates/
    └── 90-ansible-hardening.conf.j2
```
Скопируй публичный ключ:
```bash
mkdir -p files templates
cp ~/.ssh/ansible_alt_ed25519.pub files/
```
---
### Cпециально оставлен PasswordAuthentication yes на первом этапе. 
### Иначе можно отстрелить себе доступ. 
### Когда проверишь ключевой доступ — тогда отдельным этапом можно будет отключить вход по паролю.
---

### Первый запуск, когда ещё нет ключей, но есть пароль локальной учётки и root-пароль для su:
```bash
ansible-playbook -i inventory.ini bootstrap-ssh.yml \
  --ask-pass \
  --ask-become-pass
```

### Если SSH у клиентов на нестандартном порту, добавь в inventory.ini:
```ini
[alt_clients:vars]
ansible_port=22
```

### После успешного раскладывания ключа проверяешь вход уже по ключу:
```bash
ansible -i inventory.ini alt_clients \
  -m ping \
  --private-key ~/.ssh/ansible_alt_ed25519 \
  --ask-become-pass
```

### Если работает, можно прописать ключ в inventory.ini:
```ini
[alt_clients:vars]
ansible_user=localadmin
ansible_connection=ssh
ansible_ssh_private_key_file=~/.ssh/ansible_alt_ed25519
ansible_become=true
ansible_become_method=su
ansible_become_user=root
ansible_become_exe=su
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
```

### Теперь можно запускать диагностику уже массово:
```bash
ansible-playbook -i inventory.ini collect-ad-diagnostics.yml --ask-become-pass
```

### Если хочешь отдельный плейбук именно для проверки доступности SSH по паролю и su - check-su-access.yml(!)
Запуск:
```bash
ansible-playbook -i inventory.ini check-su-access.yml --ask-pass --ask-become-pass
```

Если на части машин разные пароли локальной учётки или root, Ansible начнёт страдать. 
Тогда нормальный путь — сначала выделить одну техническую локальную учётку с одинаковым паролем на всех ALT-клиентах или хотя бы на пилотной группе, раскатать ключ, а потом уже уйти от паролей. 
Если это запрещено политикой, тогда придётся вести отдельные host_vars с паролями через Ansible Vault, но это уже грязнее. 

Пример в host_vars.

Шифровать:
```bash
ansible-vault encrypt host_vars/user.domain.controller.address.yml
```
Запуск:
```bash
ansible-playbook -i inventory.ini bootstrap-ssh.yml --ask-vault-pass
```

Начинать не с Vault, а с пилотной группы 3–5 машин. 
Сначала проверить: 
- discovery доменных имён, 
- Доступность SSH, 
- su, 
- Раскладка ключа, 
- Рестарт sshd, 
Потом уже масштабировать. 

Самый безопасный порядок такой: 
- Собрать список машин из AD, 
- Отфильтровать только ALT-клиенты, 
- Сделать маленький inventory-test.ini, 
- Разложить ключ на 2–3 машины, 
- Проверить, что ключевой вход работает, 
И только потом раскатывать на весь парк.