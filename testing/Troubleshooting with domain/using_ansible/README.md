# Если у тебя есть только клиентская машина Alt Linux и нет доступа к контроллерам домена, то всё равно можно собрать довольно много компромата на состояние AD, DNS и политик.
## Начать с DNS. Очень часто все проблемы с SSSD, Kerberos и GPO оказываются не проблемами Linux, а кривым DNS.

## Что видит клиент

```bash
host -t SRV _ldap._tcp.dc._domain.controller.addresssss
```

```bash
host -t SRV _kerberos._tcp.dc._domain.controller.addresssss
```

```bash
host dc1.domain.controller.addresssss
host dc2.domain.controller.addresssss
```

---

## Посмотреть билет:

```bash
klist
```

## Получить новый:

```bash
kdestroy
kinit ИМЯ_ПОЛЬЗОВАТЕЛЯ
```

Если билет выдаётся по 20–30 секунд или сыплет ошибками — это уже интересно.

## Проверить keytab:

```bash
sudo klist -kte /etc/krb5.keytab
```

Техподдержка Базальта отдельно упоминала ошибки keytab.

## Если там:

- старые записи;
- записи только от одного контроллера;
- ошибки при обновлении,

то уже можно копать

---

# SSSD

## Самое полезное:

```bash
sssctl domain-status domain.controller.addresssss
```

```bash
sssctl domain-status
```

Смотришь:

- online/offline;
- последний успешный контакт;
- какой контроллер используется.

Ещё полезно:

```bash
sssctl user-checks USERNAME
```

```bash
id USERNAME
```

### Если доменный пользователь определяется по полминуты — это ненормально.

## Дальше лог SSSD

```bash 
journalctl -u sssd
```
```bash
grep -i error /var/log/sssd/*
```
```bash
grep -i krb5 /var/log/sssd/*
```

## Ищем:

- Offline
- LDAP error
- KDC unreachable
- Cannot contact server
- No such object

---

# Доменные политики. Используется GPOA

```bash
gpupdate
```
Или
```bash
gpoa
```
Или
```bash
time gpupdate
```
Смотреть на:

- сколько реально длится применение;
- на какой политике подвисает.

Потом логи:
```bash
journalctl | grep -i gpo
```
Или
```bash
journalctl | grep -i policy
```

---
### Техподдержка прямо пишет:
### "ввести АРМ в группу, исключающую групповые политики, затем применять политики поочерёдно до воспроизведения ошибки."
### То есть они сами подозревают именно GPO.
---

# SYSVOL
## Самая интересная вещь, которую можно сделать без доступа к серверу, — посмотреть, что клиент вообще получает из SYSVOL
```bash
smbclient -k //dc1.domain.controller.addresssss/SYSVOL 
```
Или
```bash
smbclient -k //domain.controller.addresssss/SYSVOL
```

### Kerberos очень не любит расхождение времени:

```bash
timedatectl
```
```bash
chronyc sources
```
```bash
chronyc tracking
```
### Если клиент живёт по одному времени, а контроллер по другому, начинаются чудеса.

## Если бы я оказался на твоём месте и хотел понять, насколько всё плохо, я бы собрал один архив с результатами:
```bash
hostname -f

realm list

sssctl domain-status

klist

sudo klist -kte /etc/krb5.keytab

host -t SRV _ldap._tcp.dc._domain.controller.addresssss

host -t SRV _kerberos._tcp.dc._domain.controller.addresssss

id ДОМЕННЫЙ_ПОЛЬЗОВАТЕЛЬ

time getent passwd ДОМЕННЫЙ_ПОЛЬЗОВАТЕЛЬ

journalctl -u sssd -b

timedatectl
```

### По этим данным уже можно довольно точно понять, проблема больше в:

- DNS;
- Kerberos;
- SSSD;
- GPO;
или в самих контроллерах домена.

### А если удастся получить хотя бы обычный доменный аккаунт с правом чтения LDAP, то можно ещё и напрямую опросить AD с Linux и увидеть много интересного без доступа администратора домена.