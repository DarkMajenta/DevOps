# Ниже рабочая схема. В ней ничего не требует доступа на контроллер домена. Всё выполняется с клиента, где у тебя есть root.

---

## Первый скрипт — основной сборщик диагностики - ad-client-diagnostic.sh

Запуск на одной машине:
```bash
chmod +x ad-client-diagnostic.sh
sudo ./ad-client-diagnostic.sh domain.controller.address 'DOMAIN\username'
```

Если доменного пользователя не хочешь светить или не нужен тест конкретного пользователя:
```bash
sudo ./ad-client-diagnostic.sh domain.controller.address
```

### Что этот скрипт даст: состояние DNS, SRV-записей домена, Kerberos, keytab, SSSD, GPOA/gpupdate, SYSVOL-доступ, порты контроллеров, системные журналы, косвенные признаки проблем с Kaspersky и сетевой доступностью центра лицензирования. Это как раз то, что можно собрать с клиента без прав на сервер.

---

## Второй скрипт — быстрый чек, чтобы не собирать большой архив каждый раз - ad-client-quick-check.sh

Запуск:
```bash
chmod +x ad-client-quick-check.sh
sudo ./ad-client-quick-check.sh domain.controller.address 'DOMAIN\username'
```

---

## Теперь вариант через Ansible:

```
ad-diagnostics/
├── inventory.ini
├── collect-ad-diagnostics.yml
├── files/
│   └── ad-client-diagnostic.sh
└── collected/
```

### Если вход по ключу:

```
[alt_clients:vars]
ansible_user=localadmin
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_become=true
ansible_become_method=sudo
ad_domain=domain.controller.address
test_user=
```

Запуск:
```bash
ansible-playbook -i inventory.ini collect-ad-diagnostics.yml
```
Если нужно указать тестового пользователя при запуске:
```bash
ansible-playbook -i inventory.ini collect-ad-diagnostics.yml \
  -e "test_user='DOMAIN\\username'"
```

### После выполнения архивы окажутся в ./collected/имя_хоста/tmp/...tar.gz

### Если хочется сделать совсем аккуратно, для быстрой диагностики без архивов - quick-ad-check.yml

Запуск:
```bash
ansible-playbook -i inventory.ini quick-ad-check.yml
```

Что потом искать в результатах. 
По DNS: 
- должны быть нормальные SRV-записи _ldap._tcp.dc._msdcs.домен и _kerberos._tcp.dc._msdcs.домен
Они должны возвращать оба контроллера домена, а имена контроллеров должны резолвиться в правильные адреса.
Если один контроллер выпал, если записи ведут на старые имена, если контроллеры отдают разные ответы - это уже предмет разговора с админом. 
По Kerberos: 
 - В /etc/krb5.keytab должны быть актуальные записи для хоста, не мусор от старого имени машины. 
Если keytab битый, старый или не совпадает с именем хоста - SSSD будет вести себя нестабильно. 
По SSSD: 
- опасны offline, 
- KDC unreachable, 
- Cannot contact any KDC, LDAP server is unavailable, 
- Preauthentication failed, 
- Clock skew too great, 
- No such object, 
- GPO access check failed, 
- долгие таймауты. 
По GPOA: 
- Важны ошибки применения конкретных политик и время выполнения gpupdate. 
Если чистая машина без политик работает нормально, а после применения политик виснет, то тебе нужен не спор, а таблица: 
- хост, 
- время логина, 
- время gpupdate, 
- ошибки SSSD, 
- ошибки GPOA, 
- наличие ошибок keytab.