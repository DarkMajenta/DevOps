# Если у тебя есть только клиентская машина Alt Linux и нет доступа к контроллерам домена, то всё равно можно собрать довольно много компромата на состояние AD, DNS и политик.
## Начать с DNS. Очень часто все проблемы с SSSD, Kerberos и GPO оказываются не проблемами Linux, а кривым DNS.

---

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
---