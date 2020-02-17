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
declare -a COMANDOS=('ldapsearch' 'zmmailbox' 'zmshutil' 'mysqldump');

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
