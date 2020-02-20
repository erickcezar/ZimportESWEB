# ZimportESWEB
Ferramenta importação Zimbra

Esta ferramenta esta sendo desenvolvida com o objetivo de migrar um conta de e-mail de Zimbra para outro servidor Zimbra.
A ideia é fazer essa migração coletando os dados diretamente do LDAP e do MySQL, e migrar para o novo servidor sem à necessidade de fazer o backup através do zmmbailbox utilizando o .tgz.
Dessa forma, podemos ganhar velocidade coletando diretamente os dados dentro da estrutura do Zimbra e realizar o rsync dos arquivos de textos, ao invés de aguardar o tempo de compactação e depois o tempo de sincronizar as caixas de e-mail compactadas para o novo servidor.
A ferramenta ainda está em fase de desenvolvimento, porém muitos do comandos podem ser utilizados diariamente na rotina de um administrador do Zimbra.

Muitas das ideias e códigos vieram da ferramenta Z2Z, desenvolvida pelo pessoal da BKTech Brasil.
Deixarei o link do github para que possam acessar: https://github.com/BktechBrazil/Z2Z
