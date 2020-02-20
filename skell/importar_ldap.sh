#/bin/bash

# Definindo variaveis de ambiente do zimbra
source ~/bin/zmshutil
zmsetvars

# Funcoes e variaveis para o utilitario
NORMAL_TEXT="printf \e[1;34m%-6s\e[m\n" #Azul
ERROR_TEXT="printf \e[1;31m%s\e[0m\n" #Vermelho
INFO_TEXT="printf \e[1;33m%s\e[0m\n" #Amarelo
CHOICE_TEXT="printf \e[1;32m%s\e[0m\n" #Verde
NO_COLOUR="printf \e[0m" #Branco
SERVER_HOSTNAME=$zimbra_server_hostname
SESSION=`date +"%d_%b_%Y-%H-%M"`
SESSION_LOG="registro-$SESSION.log"

# Confirma se esta sendo executado com o usuario zimbra
if [ "$(whoami)" != "zimbra" ]; then
	$ERROR_TEXT "Esse comando deve ser executado como Zimbra."
	exit 1
fi

# Arquivos necessarios para execucao
declare -a ARQUIVOS_IMPORT=('APELIDOS.ldif' 'CONTAS.ldif' 'COS.ldif' 'LISTAS.ldif');

for i in "${ARQUIVOS_IMPORT[@]}"
do
	if [ -r $i ]; then
		$INFO_TEXT "OK: Arquivo $i encontrado"
		else
			$ERROR_TEXT  "ERRO: Arquivo $i nao encontrado ou sem permissao de leitura."
			exit 1
		fi
done

# Obtendo hostname nas entradas para confirmar se corresponde ao hostname do servidor
LDIF_HOSTNAME=`grep zimbraMailHost CONTAS.ldif | uniq | awk '{print $2}'`
if [ "$SERVER_HOSTNAME" != "$LDIF_HOSTNAME" ]; then
	$ERROR_TEXT "ERRO: O hostname do servidor nao corresponde ao hostname dos arquivos de importacao"
	$INFO_TEXT "Hostname do servidor: $SERVER_HOSTNAME"
	$INFO_TEXT "Hostname nos arquivos para importacao: $LDIF_HOSTNAME"
	exit 1
fi

# Comandos necessarios para a execucao
declare -a COMANDOS=('ldapsearch' 'zmhostname' 'zmshutil');

for i in "${COMANDOS[@]}"
do
	type $i >/dev/null 2>/dev/null
	if [ $? != 0 ]; then
		$ERROR_TEXT "ERRO: O comando $i nao foi encontrado, abortando execucao."
		exit 1
	fi
done

clear

# Iniciando rotinas de importacao
echo ""
echo ""
$INFO_TEXT "Essa versao NAO cria ou importa os dominios, somente continue se ja tiver criado os dominios do ambiente"
$INFO_TEXT "Importacao iniciada em: $SESSION" &> $SESSION_LOG
$NORMAL_TEXT "Registro da sessao: $SESSION_LOG"

# Interatividade: execucao da importacao
test_exec()
{
read -p "Deseja iniciar a importacao das CLASSES DE SERVICO, CONTAS, NOMES ALTERNATIVOS E LISTAS E DISTRIBUICAO (sim/nao)?" choice
case "$choice" in
	y|Y|yes|s|S|sim ) $NORMAL_TEXT "Iniciando Z2Z";;
	n|N|no|nao ) exit 0;;
	* ) test_exec ;;
esac
}

test_exec # executa a funcao test_exec


# Inicia importacao das classes de servico, contas, nomes alternativos e listas de distribuicao

# Importacao das cos, contas, apelidos e listas

$INFO_TEXT "Importando classes de servico"
ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f COS.ldif &>> $SESSION_LOG
$INFO_TEXT "Importando contas"
ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f CONTAS.ldif &>> $SESSION_LOG
$INFO_TEXT "importando nomes alternativos"
ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f APELIDOS.ldif &>> $SESSION_LOG
$INFO_TEXT "importando listas de distribuicao"
ldapadd -c -x -H ldap://$zimbra_server_hostname -D $zimbra_ldap_userdn -w $zimbra_ldap_password -f LISTAS.ldif &>> $SESSION_LOG
#
