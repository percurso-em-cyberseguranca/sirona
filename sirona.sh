#!/bin/bash

# Função para imprimir o banner com figlet
print_banner() {
    echo "*************************************************"
    figlet -f slant "Sirona"
    echo "*************************************************"
    echo "desenvolvido pela turma VII"
    echo "*************************************************"
}

# Verifica se o domínio foi fornecido
if [ -z "$1" ]; then
    echo "Uso: $0 <domínio>"
    exit 1
fi

# Imprimir o banner
print_banner

# Definir o domínio alvo
DOMAIN=$1

# Criar diretórios para saída
OUTPUT_DIR="output"
SCREENSHOTS_DIR="${OUTPUT_DIR}/screenshots"
mkdir -p $OUTPUT_DIR
mkdir -p $SCREENSHOTS_DIR

# Arquivos temporários
SUBDOMAINS_TMP="${OUTPUT_DIR}/subdomains_tmp.txt"
SUBDOMAINS="${OUTPUT_DIR}/subdomains.txt"
ALIVE_SUBDOMAINS="${OUTPUT_DIR}/alive_subdomains.txt"
TECHNOLOGIES="${OUTPUT_DIR}/technologies.txt"

# Limpar arquivos antigos
> $SUBDOMAINS_TMP
> $SUBDOMAINS
> $ALIVE_SUBDOMAINS
> $TECHNOLOGIES

# Executar ferramentas de reconhecimento de subdomínios
echo "[*] Executando Sublist3r..."
sublist3r -d $DOMAIN -o $SUBDOMAINS_TMP

echo "[*] Executando Findomain..."
findomain -t $DOMAIN -q >> $SUBDOMAINS_TMP

echo "[*] Executando Subfinder..."
subfinder -d $DOMAIN -o $SUBDOMAINS_TMP

echo "[*] Executando Assetfinder..."
assetfinder --subs-only $DOMAIN >> $SUBDOMAINS_TMP

# Remover duplicados e organizar os subdomínios encontrados
sort -u $SUBDOMAINS_TMP > $SUBDOMAINS

# Verificar quais subdomínios estão vivos e protocolo usado (HTTP ou HTTPS)
echo "[*] Verificando subdomínios vivos..."
while IFS= read -r subdomain; do
    echo "Verificando http://$subdomain..."
    if curl -s --head --request GET http://$subdomain | grep "HTTP/1.1 200 OK" > /dev/null; then
        echo "Subdomínio ativo: http://$subdomain"
        echo "http://$subdomain" >> $ALIVE_SUBDOMAINS
    else
        echo "http://$subdomain não está ativo."
    fi
    echo "Verificando https://$subdomain..."
    if curl -s --head --request GET https://$subdomain | grep "HTTP/1.1 200 OK" > /dev/null; then
        echo "Subdomínio ativo: https://$subdomain"
        echo "https://$subdomain" >> $ALIVE_SUBDOMAINS
    else
        echo "https://$subdomain não está ativo."
    fi
done < $SUBDOMAINS

# Capturar prints das telas dos subdomínios vivos
echo "[*] Capturando prints das telas..."
while IFS= read -r url; do
    subdomain=$(echo $url | sed 's|https\?://||')
    echo "Capturando print de $url..."
    if chromium --headless --no-sandbox --screenshot="${SCREENSHOTS_DIR}/${subdomain}.png" $url; then
        echo "Screenshot capturada para $url"
    else
        echo "Falha ao capturar screenshot para $url"
    fi
done < $ALIVE_SUBDOMAINS

# Identificar tecnologias usadas pelos subdomínios vivos
echo "[*] Identificando tecnologias usadas..."
while IFS= read -r url; do
    echo "Identificando tecnologias em $url..."
    whatweb --no-errors -a 3 $url >> $TECHNOLOGIES
done < $ALIVE_SUBDOMAINS

echo "[*] Reconhecimento concluído. Resultados salvos em $OUTPUT_DIR"