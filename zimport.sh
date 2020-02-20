#!/bin/bash
###   ZimportESWEB - Mantido por ESWEB <https://www.esweb.com.br>                 ###

###   VERSAO 1.0.0 (17/02/2020)

. func.sh

# Carregar Zimport
clear
#cat banner.txt
echo ""
#

# Confirmar execucao com usuario zimbra
Run_as_Zimbra
separator_char

# Confirmar continuacao script

test_exec
separator_char

# Comandos necessários
declare -a COMANDOS=('ldapsearch' 'zmshutil' 'mysqldump');

Check_Command
separator_char

# Variaveis ambiente zimbra
source ~/bin/zmshutil
zmsetvars

# Definindo nome servidor com variavel do amabiente
ZIMBRA_HOSTNAME=$zimbra_server_hostname
# Definindo usuario bind ldap do zimbra
ZIMBRA_BINDDN=$zimbra_ldap_userdn

# Diretorios

DIRETORIO=$WORKDIR
Check_Directory
separator_char
DIRETORIO="`pwd`/skell"
Check_Directory
separator_char
DESTINO=$WORKDIR
mkdir $WORKDIR/alias #Cria diretorio temporario para exportar os nomes alternativos

# Definindo dominio
Enter_Domain
separator_char

# Buscando todas as contas relacionadas ao domínio, exceto contas de sistema
MAILBOX_LIST=`zmprov -l gaa | grep -v -E "admin@|virus-|ham.|spam.|galsync" | grep $DOMAIN`

# Tratando domain para usar no LDAP
DOMAIN_LDAP=$(echo $DOMAIN | sed 's/\./,dc=/g' | sed 's/^/dc=/g')

# Exportando classe de servico
$NORMAL_TEXT "EXPORTANDO CLASSES DE SERVICO"
separator_char
ldapsearch -x -H ldap://$ZIMBRA_HOSTNAME -D $ZIMBRA_BINDDN -w $zimbra_ldap_password -b "cn=$DOMAIN,cn=cos,cn=zimbra" -LLL "(objectclass=zimbraCOS)" > $DESTINO/COS.ldif
$INFO_TEXT "CLASSES DE SERVICO EXPORTADAS COM SUCESSO: $DESTINO/COS.ldif"
separator_char

# Exportando contas - desconsiderando contas de serviço do zimbra
$NORMAL_TEXT  "EXPORTANDO CONTAS"
separator_char
ldapsearch -x -H ldap://$ZIMBRA_HOSTNAME -D $ZIMBRA_BINDDN -w $zimbra_ldap_password -b $DOMAIN_LDAP -LLL '(&(!(zimbraIsSystemResource=TRUE))(!(zimbraIsAdminAccount=TRUE))(objectClass=zimbraAccount))' > $DESTINO/CONTAS.ldif
$INFO_TEXT "CONTAS EXPORTADAS COM SUCESSO: $DESTINO/CONTAS.ldif"
separator_char

# Exportando nomes alternativos
$NORMAL_TEXT  "EXPORTANDO NOMES ALTERNATIVOS"
separator_char

ldapsearch -x -H ldap://$ZIMBRA_HOSTNAME -D $ZIMBRA_BINDDN -w $zimbra_ldap_password  -b $DOMAIN_LDAP -LLL '(&(!(uid=root))(!(uid=postmaster))(objectclass=zimbraAlias))' uid | grep ^uid | awk '{print $2}' > $DESTINO/lista_contas.ldif

touch $DESTINO/APELIDOS.ldif # Criando arquivo para que caso esteja vazio, não apresentar erro na importacao do LDAP

for MAIL in $(cat $DESTINO/lista_contas.ldif);
do 
	ldapsearch -x -H ldap://$ZIMBRA_HOSTNAME -D $ZIMBRA_BINDDN -w $zimbra_ldap_password -b $DOMAIN_LDAP -LLL "(&(uid=$MAIL)(objectclass=zimbraAlias))" > $DESTINO/alias/$MAIL.ldif
	cat $DESTINO/alias/*.ldif > $DESTINO/APELIDOS.ldif
done 

$INFO_TEXT "NOMES ALTENATIVOS EXPORTADOS COM SUCESSO: $DESTINO/APELIDOS.ldif"
separator_char

# Exportando lista de distribuicao
$NORMAL_TEXT  "EXPORTANDO LISTAS DE DISTRIBUICAO"
separator_char
ldapsearch -x -H ldap://$ZIMBRA_HOSTNAME -D $ZIMBRA_BINDDN -w $zimbra_ldap_password -b $DOMAIN_LDAP -LLL "(|(objectclass=zimbraGroup)(objectclass=zimbraDistributionList))" > $DESTINO/LISTAS.ldif
$INFO_TEXT "LISTAS DE DISTRIBUICAO EXPORTADAS COM SUCESSO: $DESTINO/LISTAS.ldif"
separator_char

# Limpa os arquivos temporarios criados no diretorio export
Clear_Workdir

# Alterar hostname do servidor
Replace_Hostname
separator_char

# Copia script de importacao e banner simples 
cp skell/importar_ldap.sh export/
chmod +x export/importar_ldap.sh

# Cria o diretorio backup_mailbox
if [ ! -d $WORKDIR/backup_mailbox ]; then
	mkdir $WORKDIR/backup_mailbox
fi

# Criando script para importacao no servidor destino 
true > $DESTINO/backup_mailbox/script_export.sh
echo "#!/bin/bash" >> $DESTINO/backup_mailbox/script_export.sh
echo "" >> $DESTINO/backup_mailbox/script_export.sh
echo "# Antes de realizar a importacao do mboxgroup deve ser realizado a importacao do LDAP" >> $DESTINO/backup_mailbox/script_export.sh
echo "source ~/bin/zmshutil" >> $DESTINO/backup_mailbox/script_export.sh
echo "zmsetvars" >> $DESTINO/backup_mailbox/script_export.sh
echo "" >> $DESTINO/backup_mailbox/script_export.sh

# Realizar o dump relacionado as caixas postais e cria script para importacao
for MAIL in $MAILBOX_LIST
do
	ID=`zmprov gmi $MAIL | grep mailboxId | cut -d ":" -f 2 | tr -d " "`
	MBOXGROUP=`expr $ID % 100`
	if [ $MBOXGROUP -eq 0 ]; then # Testa se mboxgroup eh 0, se for o valor deve ser 100
		MBOXGROUP=100
	fi
	
	TABELAS=`mysql mboxgroup$MBOXGROUP --batch --skip-column-names -e "show tables"`
	if [ $? -ne 0 ]; then # Verifica se mboxgroup existe no banco de dados
		$ERROR_TEXT "ERRO: O mboxgroup não exite."
		exit 1
	fi
	
	SOCKET=`netstat -ln | grep -o -m 1 -E '\S*mysqld?\.sock'`
	if [ $? -ne 0 ]; then # Testa se o banco socket do mysql foi encontrado ou esta ativo
		$ERROR_TEXT "ERRO: O socket do mysql nao foi encontrado."
		exit 1
	fi
	
	for i in $TABELAS
	do
		mysqldump --no-create-info --extended-insert=FALSE --user=zimbra --password=$zimbra_mysql_password mboxgroup$MBOXGROUP $i --where="mailbox_id=$ID" --socket=$SOCKET >> $DESTINO/backup_mailbox/$(echo $MAIL | tr [.@] _)\_mboxgroup\.sql
	done

	# Insercao mysqldump no script

	echo "#Insere o mysqldump no mboxgroup relacionado ao e-mail" >> $DESTINO/backup_mailbox/script_export.sh
	echo "ID=\$(zmprov gmi $MAIL | grep mailboxId | cut -d ":" -f 2 | tr -d \" \")" >> $DESTINO/backup_mailbox/script_export.sh
	echo "MBOXGROUP=\$(expr \$ID % 100)" >> $DESTINO/backup_mailbox/script_export.sh
	echo "if [ \$MBOXGROUP -eq 0 ]; then MBOXGROUP=100; fi" >> $DESTINO/backup_mailbox/script_export.sh
	echo "mysql mboxgroup\$MBOXGROUP < $(echo $MAIL | tr [.@] _).sql" >> $DESTINO/backup_mailbox/script_export.sh
	echo "# Importacao mboxgroup finalizada" >> $DESTINO/backup_mailbox/script_export.sh
	echo "# Iniciar importacao checkpoints" >> $DESTINO/backup_mailbox/script_export.sh
	echo "" >> $DESTINO/backup_mailbox/script_export.sh

	# Obtendo valores dos checkpoints

	ITEMID_CHECKPOINT=`mysql zimbra --batch --skip-column-names -e "select item_id_checkpoint from mailbox where id=$ID"`
	SIZE_CHECKPOINT=`mysql zimbra --batch --skip-column-names -e "select size_checkpoint from mailbox where id=$ID"`
	CHANGE_CHECKPOINT=`mysql zimbra --batch --skip-column-names -e "select change_checkpoint from mailbox where id=$ID"`
	CONTACT_COUNT=`mysql zimbra --batch --skip-column-names -e "select contact_count from mailbox where id=$ID"`
	TRACKING_SYNC=`mysql zimbra --batch --skip-column-names -e "select tracking_sync from mailbox where id=$ID"`
	TRACKING_IMAP=`mysql zimbra --batch --skip-column-names -e "select tracking_imap from mailbox where id=$ID"`
	LAST_SOAP_ACCESS=`mysql zimbra --batch --skip-column-names -e "select last_soap_access from mailbox where id=$ID"`
	LAST_PURGE_AT=`mysql zimbra --batch --skip-column-names -e "select last_purge_at from mailbox where id=$ID"`
	
	

	# mysqldump zimbra mailbox_metadata
	mysqldump --no-create-info --extended-insert=FALSE --user=zimbra --password=$zimbra_mysql_password zimbra mailbox_metadata --where="mailbox_id=$ID" --socket=$SOCKET >> $DESTINO/backup_mailbox/$(echo $MAIL | tr [.@] _)\_metadata\.sql

	# mysqldump zimbra mailbox_metadata
   	mysqldump --no-create-info --extended-insert=FALSE --user=zimbra --password=$zimbra_mysql_password zimbra scheduled_task --where="mailbox_id=$ID" --socket=$SOCKET >> $DESTINO/backup_mailbox/$(echo $MAIL | tr [.@] _)\_schedule_\task\.sql
	# mysql update com os checkpoints e importando metadata e schedule_task
	echo "# Realizando update na tabela mailbox_item na database zimbra" >> $DESTINO/backup_mailbox/script_export.sh
	echo "mysql zimbra --batch --skip-column-names -e \"update mailbox_item set item_id_checkpoint=$ITEMID_CHECKPOINT, size_checkpoint=$SIZE_CHECKPOINT, change_checkpoint=$CHANGE_CHECKPOINT, contact_count=$CONTACT_COUNT, tracking_sync=$TRACKING_SYNC, tracking_imap=$TRACKING_IMAP, last_soap_access=$LAST_SOAP_ACCESS, last_purge_at=$LAST_PURGE_AT where id=\$ID\"" >> $DESTINO/backup_mailbox/script_export.sh
	echo "mysql zimbra < $(echo $MAIL | tr [.@] _)_metadata.sql" >> $DESTINO/backup_mailbox/script_export.sh
	echo "mysql zimbra < $(echo $MAIL | tr [.@] _)_schedule_task.sql" >> $DESTINO/backup_mailbox/script_export.sh

done

chmod +x $DESTINO/backup_mailbox/script_export.sh

$INFO_TEXT "Script para importacao criado com sucesso!"
$CHOICE_TEXT "Backup finalizado!"
