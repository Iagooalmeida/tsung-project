# Tsung Load Testing - Guia de Configuração

## 📋 Visão Geral

Este projeto configura um ambiente completo de teste de carga usando **Tsung** com Docker, incluindo geração automática de relatórios e visualização web.

## 🏗️ Estrutura do Projeto

```
tsung-project/
├── config/
│   └── test.xml              # Configuração de teste Tsung
├── results/                  # Relatórios gerados (auto-criado)
│   └── YYYYMMDD-HHMM/       # Diretório por teste
│       ├── report.html       # Relatório completo
│       ├── graph.html        # Gráficos interativos
│       ├── index_viewer.html # Página inicial navegável
│       ├── images/           # Gráficos PNG (gnuplot)
│       └── dados...
├── nginx/
│   └── default.conf          # Configuração do servidor web
├── tsung-templates/          # Templates personalizados (opcional)
├── create_index.sh           # Script para gerar index_viewer.html
├── docker-compose.yml        # Orquestração dos serviços
├── Dockerfile               # Container Tsung personalizado
└── README.md                # Este arquivo
```

## 🚀 Início Rápido

### 1. Executar Teste

```powershell
# Iniciar containers e executar teste
docker compose up -d --build --remove-orphans

# Ou apenas reiniciar para novo teste
docker compose restart tsung
```

### 2. Acessar Relatórios

- **Listagem de Testes:** http://localhost:8080
- **Dashboard Live:** http://localhost:8091 (durante execução)
- **Teste Específico:** http://localhost:8080/results/YYYYMMDD-HHMM/index_viewer.html

## 🔧 Configuração Manual

### Gerar Relatórios Manualmente

Se os relatórios não forem gerados automaticamente:

```powershell
# 1. Identificar o teste mais recente
docker compose exec tsung bash -lc "ls -1 /root/.tsung/log | tail -n 1"

# 2. Gerar relatórios com gráficos interativos (substitua a data/hora)
docker compose exec tsung bash -lc "cd /root/.tsung/log/YYYYMMDD-HHMM && /usr/lib/tsung/bin/tsung_stats.pl --dygraph ."

# 3. (Opcional) Gerar página inicial navegável do run
docker compose exec tsung bash -lc "bash /create_index.sh 'YYYYMMDD-HHMM' '/root/.tsung/log/YYYYMMDD-HHMM'"
```

### Exemplo Completo

```powershell
# Para o teste 20250916-0535
docker compose exec tsung bash -lc "cd /root/.tsung/log/20250916-0535 && /usr/lib/tsung/bin/tsung_stats.pl --dygraph . && bash /create_index.sh '20250916-0535' '/root/.tsung/log/20250916-0535'"
```

## 📊 Tipos de Relatórios

### 1. **report.html** - Relatório Completo

- Estatísticas detalhadas com Bootstrap
- Gráficos estáticos (gnuplot) como apoio
- Análise de performance completa

### 2. **graph.html** - Gráficos Interativos  

- Visualizações com zoom/pan (Dygraph)
- Interativos e responsivos

### 3. **index_viewer.html** - Página Inicial  

- Navegação amigável entre relatórios
- Links diretos para report.html e graph.html
- Informações do teste

## ⚙️ Configuração Avançada

### Personalizar Teste (config/test.xml)

```xml
<?xml version="1.0"?>
<!DOCTYPE tsung SYSTEM "/usr/share/tsung/tsung-1.0.dtd">
<tsung loglevel="notice">
  <!-- Configuração do teste -->
  <clients>
    <client host="localhost" use_controller_vm="true" maxusers="10"/>
  </clients>

  <!-- Servidor alvo -->
  <servers>
    <server host="httpbin.org" port="443" type="ssl"/>
  </servers>

  <!-- Cenário de carga -->
  <load>
    <arrivalphase phase="1" duration="60" unit="second">
      <users arrivalrate="1" unit="second"/>
    </arrivalphase>
  </load>

  <!-- Sessões de teste -->
  <sessions>
    <session name="http_test" probability="100" type="ts_http">
      <request>
        <http url="/get" method="GET"/>
      </request>
      <request>
        <http url="/status/200" method="GET"/>
      </request>
      <request>
        <http url="/ip" method="GET"/>
      </request>
    </session>
  </sessions>
</tsung>
```

### Tags e Transactions no Relatório

Use `request@tag` para classificar requisições (ex.: `navegacao`, `compra`).

Agrupe passos de negócio em `<transaction name="...">` para métricas agregadas.

Exemplo (trecho simplificado):

```xml
<session name="processo_compra" probability="30" type="ts_http">
  <transaction name="fluxo_compra">
    <request tag="compra"><http url="/get" method="GET"/></request>
    <thinktime value="2" random="true"/>
    <request tag="compra">
      <http url="/post" method="POST" content_type="application/json"
            contents='{"action":"login","usuario":"cliente123","senha":"senha456"}'/>
    </request>
    <!-- ... -->
  </transaction>
</session>
```

Onde ver no relatório:

- Em `report.html`, na seção “Transactions”.
- Em “Per tag”, para métricas por `tag`.

### Personalizar Viewer Web (nginx/default.conf)

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Redirecionar raiz para results
    location = / {
        return 301 /results/;
    }

    # Servir arquivos de resultado
    location /results/ {
        alias /usr/share/nginx/html/results/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }

    # Servir arquivos estáticos
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## 🐛 Resolução de Problemas

### Problema: Relatórios não são gerados automaticamente

**Solução:** Gerar manualmente conforme instruções acima

### Problema: Dashboard Tsung (8091) mostra erro "tsung_stats.pl was not found"

**Causa:** O dashboard procura o script em `/usr/lib/tsung/bin/` mas ele está em `/usr/lib/x86_64-linux-gnu/tsung/bin/`

**Solução:** Já corrigido no Dockerfile com link simbólico. Se persistir:

```powershell
# Criar link simbólico manualmente
docker compose exec tsung bash -c "mkdir -p /usr/lib/tsung/bin && ln -sf /usr/lib/x86_64-linux-gnu/tsung/bin/tsung_stats.pl /usr/lib/tsung/bin/tsung_stats.pl"

# Reconstruir container se necessário
docker compose build --no-cache
docker compose up -d
```

### Problema: Containers não iniciam

```powershell
# Verificar logs
docker compose logs tsung
docker compose logs viewer

# Reconstruir imagens
docker compose build --no-cache
docker compose up -d
```

### Problema: Permissões de arquivo

```powershell
# No Windows, verificar se Docker tem acesso às pastas
# Configurar compartilhamento de drives no Docker Desktop
```

### Problema: Porta já em uso

```powershell
# Verificar portas ocupadas
netstat -an | findstr "8080\|8091"

# Alterar portas no docker-compose.yml se necessário
```

## 📁 Comandos Úteis

### Gerenciamento de Containers

```powershell
# Iniciar/parar
docker compose up -d
docker compose down

# Reconstruir
docker compose build --no-cache

# Logs
docker compose logs -f tsung
docker compose logs -f viewer

# Acessar container
docker compose exec tsung bash
```

### Verificação de Testes

```powershell
# Listar testes
ls results/

# Verificar arquivos de um teste
ls results/YYYYMMDD-HHMM/

# Ver logs de um teste específico
docker compose exec tsung bash -lc "tail -n 200 /root/.tsung/log/YYYYMMDD-HHMM/tsung.log"

### Script de atalho: start-run.ps1

Para iniciar um novo teste, aguardar a finalização, gerar os relatórios (Dygraph) e criar a página `index_viewer.html` automaticamente, use o script:

```powershell
# Executar a partir da raiz do projeto
./scripts/start-run.ps1

# Opções:
# -ConfigPath: caminho do XML (default: /config/test.xml)
# -Latest: habilita ação extra futura (placeholder)

# Exemplo: apontando para um XML específico
./scripts/start-run.ps1 -ConfigPath "/config/test.xml"
```

Ao finalizar, o script imprime os links prontos para abrir no navegador:

- Dashboard: [http://localhost:8091/](http://localhost:8091/)
- Index do run: [http://localhost:8080/results/YYYYMMDD-HHMM/index_viewer.html](http://localhost:8080/results/YYYYMMDD-HHMM/index_viewer.html)
- Relatório: [http://localhost:8080/results/YYYYMMDD-HHMM/report.html](http://localhost:8080/results/YYYYMMDD-HHMM/report.html)
- Gráficos: [http://localhost:8080/results/YYYYMMDD-HHMM/graph.html](http://localhost:8080/results/YYYYMMDD-HHMM/graph.html)


### Limpeza

```powershell
# Remover todos os resultados
Remove-Item -Recurse -Force results/*

# Remover containers
docker compose down --volumes

# Remover imagens
docker rmi tsung-project-tsung
```

## 🌐 URLs de Acesso

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Viewer Principal** | [http://localhost:8080](http://localhost:8080) | Lista todos os testes |
| **Dashboard Tsung** | [http://localhost:8091](http://localhost:8091) | Monitor em tempo real |
| **Teste Específico** | [http://localhost:8080/results/YYYYMMDD-HHMM/index_viewer.html](http://localhost:8080/results/YYYYMMDD-HHMM/index_viewer.html) | Navegação do teste |
| **Relatório Completo** | [http://localhost:8080/results/YYYYMMDD-HHMM/report.html](http://localhost:8080/results/YYYYMMDD-HHMM/report.html) | Análise detalhada |
| **Gráficos** | [http://localhost:8080/results/YYYYMMDD-HHMM/graph.html](http://localhost:8080/results/YYYYMMDD-HHMM/graph.html) | Visualizações |

## 📝 Notas Importantes

1. **Formato de Data:** Os testes são salvos no formato `YYYYMMDD-HHMM` (ex: `20250916-0535`)

2. **Estilo de Gráficos:** Configurado para usar **gnuplot** (estilo clássico) ao invés de Dygraph

3. **Persistência:** Os resultados são salvos na pasta `./results/` e persistem entre reinicializações

4. **Navegação:** Use sempre `index_viewer.html` como ponto de entrada para cada teste

5. **Performance:** O teste padrão executa por 60 segundos com 10 usuários simultâneos contra httpbin.org

## 🔄 Workflow Típico

1. **Executar:** `docker compose up -d --build --remove-orphans`
2. **Aguardar:** ~60-90 segundos para completar
3. **Verificar:** Acessar [http://localhost:8080](http://localhost:8080)
4. **Se necessário:** Gerar relatórios manualmente
5. **Analisar:** Navegar pelos relatórios gerados

---

**Desenvolvido para testes de carga com Tsung + Docker**  
*Versão: 1.0 - Setembro 2025*

## ✅ Status Atual da Configuração

### 🎯 Funcionalidades Testadas e Aprovadas

- ✅ **Container Tsung**: Funcionando com Debian Bookworm-slim + dependências
- ✅ **Viewer Web**: Nginx servindo relatórios em [http://localhost:8080](http://localhost:8080)
- ✅ **Teste Simples**: `config/test_simple.xml` validado e executando
- ✅ **Geração de Relatórios**: Procedure manual funcionando perfeitamente
- ✅ **Gráficos**: Usando gnuplot (estilo clássico preferido)
- ✅ **Navegação**: Interface web com Bootstrap

### 📊 Último Teste Executado

- **ID**: 20250917-0105
- **Configuração**: test_simple.xml (30s, usuários a cada 2s)
- **Target**: httpbin.org (HTTPS)
- **Resultado**: ✅ Sucesso completo
- **Relatórios**: Disponíveis em [http://localhost:8080/20250917-0105/](http://localhost:8080/20250917-0105/)

### 🔧 Procedure Manual de Relatórios (Testado)

```bash
# Executar dentro do container após cada teste
docker compose exec tsung bash -c "cd /root/.tsung/log/YYYYMMDD-HHMM && /usr/lib/tsung/bin/tsung_stats.pl --dygraph ."
```

### 🚀 Próximos Desenvolvimentos

1. **Testes Complexos**: Expandir para cenários de e-commerce realistas
2. **Automatização**: Melhorar scripts de geração automática
3. **Múltiplas Fases**: Implementar ramp-up/pico/ramp-down
4. **Monitoramento**: Adicionar métricas de sistema

### 📱 Acesso Rápido

- **Viewer**: [http://localhost:8080](http://localhost:8080)
- **Dashboard**: [http://localhost:8091](http://localhost:8091)  
- **Último Teste**: [http://localhost:8080/20250917-0105/report.html](http://localhost:8080/20250917-0105/report.html)

```text
├── config/
│   └── test.xml               # Configuração do teste (httpbin.org)
├── nginx/
│   └── default.conf           # Config do viewer Nginx
├── tsung-templates/
│   └── index.html.tpl         # Template sem links ts_web (para viewer estático)
├── results/                   # Logs e relatórios gerados (volumes Docker)
└── README.md                  # Este arquivo
```

## Como usar

### 1. Executar teste de carga

```powershell
# Sobe os serviços (tsung + viewer)
docker compose up -d --build --remove-orphans

# Ver logs em tempo real
docker compose logs -f tsung
```

### 2. Acessar relatórios

- **Viewer estático (recomendado)**: [http://localhost:8080/](http://localhost:8080/)
  - Lista todos os testes: [http://localhost:8080/results/](http://localhost:8080/results/)
  - Relatório específico: [http://localhost:8080/results/YYYYMMDD-HHMM/report.html](http://localhost:8080/results/YYYYMMDD-HHMM/report.html)

- **Dashboard Tsung (tempo real)**: [http://localhost:8091/](http://localhost:8091/)
  - Status ao vivo durante o teste
  - Links ts_web:* funcionam apenas aqui

### 3. Configurar testes

Edite `config/test.xml` para:

- Mudar o host de destino (`<server host="..." />`)
- Ajustar URLs das requisições (`<http url="/endpoint" />`)
- Modificar duração e carga (`<arrivalphase duration="..." />`, `maxusers`)

### 4. Limpar resultados

```powershell
# Parar serviços e limpar volumes
docker compose down -v

# Limpar diretório results (opcional)
Remove-Item -Recurse -Force .\results\*
```

## Arquivos principais

### config/test.xml  

Configuração do teste Tsung:

- **Target**: httpbin.org (HTTPS)
- **Cenário**: GET /get, /status/200, /ip
- **Carga**: 1 usuário por segundo, máximo 50, duração 1 minuto

### docker-compose.yml

- **tsung**: Executa teste e mantém webserver (8091) ativo
- **viewer**: Nginx para servir relatórios estáticos (8080)

## Troubleshooting

````markdown
### Problema: Links "ts_web:status" quebrados no viewer

**Solução**: Use [http://localhost:8080/](http://localhost:8080/) (viewer) para navegação estática ou [http://localhost:8091/](http://localhost:8091/) (Tsung) para funcionalidades dinâmicas.

### Problema: Container tsung para após o teste

**Verificar**: Flag `-k` mantém o webserver ativo. Logs em `docker compose logs tsung`.

### Problema: Relatórios não aparecem

**Verificar**:

1. Pasta `results/` existe e tem permissão
2. `tsung_stats.pl` executou (logs do container)
3. Arquivos .html foram gerados em `results/YYYYMMDD-HHMM/`

### Problema: Erro de conexão HTTP  

**Verificar**:

1. Host de destino acessível (teste manual: `curl https://httpbin.org/get`)
2. Firewall/proxy corporativo
3. Configuração SSL no `test.xml`

## Personalização

### Mudar host de teste

```xml
```
<servers>
  <server host="meu-servidor.com" port="443" type="ssl" />
</servers>
```

### Adicionar endpoints  

```xml
<session name="meu-teste" probability="100" type="ts_http">
  <request>
    <http url="/api/endpoint1" method="GET"/>
  </request>
  <thinktime value="2"/>
  <request>
    <http url="/api/endpoint2" method="POST"/>
  </request>
</session>
```

### Ajustar carga
```xml
<load>
  <arrivalphase phase="1" duration="5" unit="minute">
    <users interarrival="0.5" unit="second"/> <!-- 2 usuários/seg -->
  </arrivalphase>
</load>

<options>
  <option name="maxusers" value="200"/>
</options>
```

## Comandos úteis

```powershell
# Ver status dos containers
docker compose ps

# Logs específicos
docker compose logs -f viewer
docker compose logs -f tsung

# Reiniciar apenas o viewer
docker compose up -d viewer

# Executar comando no container tsung
docker compose exec tsung sh

# Backup de resultados
Copy-Item -Recurse .\results\ .\backup-$(Get-Date -Format 'yyyyMMdd-HHmm')\
```

## Links úteis

- [Manual do Tsung](http://tsung.erlang-projects.org/user_manual/)
- [Configuração HTTP](http://tsung.erlang-projects.org/user_manual/conf-sessions.html#http)
- [Estatísticas e Relatórios](http://tsung.erlang-projects.org/user_manual/reports.html)
- [httpbin.org](https://httpbin.org/) - API de teste HTTP  
  