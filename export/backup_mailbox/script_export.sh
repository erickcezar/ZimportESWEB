#!/bin/bash

# Antes de realizar a importacao do mboxgroup deve ser realizado a importacao do LDAP
source ~/bin/zmshutil
zmsetvars

#Insere o mysqldump no mboxgroup relacionado ao e-mail
ID=$(zmprov gmi teste@zadmin.net | grep mailboxId | cut -d : -f 2 | tr -d " ")
MBOXGROUP=$(expr $ID % 100)
if [ $MBOXGROUP -eq 0 ]; then MBOXGROUP=100; fi
mysql mboxgroup$MBOXGROUP < teste_zadmin_net.sql
# Importacao mboxgroup finalizada
# Iniciar importacao checkpoints

mysql zimbra --batch --skip-column-names -e "update mailbox_item set item_id_checkpoint=299, size_checkpoint=465579, change_checkpoint=1900, contact_count=0, tracking_sync=0, tracking_imap=0, last_soap_access=1581953231, last_purge_at=1582139558 where id=$ID"
mysql zimbra < teste_zadmin_net_metadata.sql
mysql zimbra < teste_zadmin_net_schedule_task.sql
