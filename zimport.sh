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
mkdir $WORKDIR/backup_mailbox

# Realizar o dump relacionado as caixas postais
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
		mysqldump --user=zimbra --password=$zimbra_mysql_password mboxgroup$MBOXGROUP $i --where="mailbox_id=$ID" --socket=$SOCKET >> $DESTINO/backup_mailbox/$MAIL\.sql
	done
done

$CHOICE_TEXT "Backup finalizado!"
