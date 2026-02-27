# zigbox Roadmap de Funcionalidades

Este documento lista as funcionalidades que ainda precisamos implementar para evoluir o `zigbox` de MVP para uma suíte robusta de utilitários.

## Estado Atual

Comandos já implementados:

- `ls`
- `rm`
- `find`
- `grep`
- `cat`
- `mkdir`
- `touch`
- `pwd`
- `echo`
- `cp`
- `mv`

Também já existe CI no GitHub Actions com build + smoke tests.

## Prioridade P0 (Próximos passos)

### 1) Comandos essenciais faltando

- `tree`: visualização hierárquica de diretórios
- `du`: uso de disco por arquivo/pasta
- `wc`: contagem de linhas/palavras/bytes
- `head` e `tail`: pré-visualização de arquivos
- `chmod`: alteração de permissões

### 2) Melhorias imediatas nos comandos atuais

- `cp`:
  - suporte a `-a` (preservar metadados básicos)
  - suporte a `-n` (não sobrescrever)
  - suporte a `-v` (verbose)
- `mv`:
  - suporte a `-n` e `-v`
  - melhor tratamento de destino existente (arquivo x diretório)
- `rm`:
  - suporte a `--preserve-root`
  - confirmação mais robusta para diretórios recursivos
- `grep`:
  - `-i` (case-insensitive)
  - `-n` (mostrar número da linha)
  - `-l` (somente nomes de arquivo)

### 3) Ajuda e UX

- padronizar mensagem de help em todos os comandos
- incluir exemplos em todos os `--help`
- padronizar códigos de saída (`0`, `1`, `2`) por tipo de erro

## Prioridade P1 (Estabilidade e qualidade)

### 4) Testes automatizados reais

- criar testes unitários por subcomando (não só smoke)
- criar testes de integração com cenários de FS temporário
- adicionar matriz no CI:
  - Linux
  - macOS

### 5) Compatibilidade e portabilidade

- revisar comportamento para Windows (paths, permissões, symlink)
- garantir consistência de saída ANSI em TTY e não-TTY
- validar fallback quando recursos POSIX não estiverem disponíveis

### 6) Performance

- otimizar `grep` para arquivos grandes (streaming)
- melhorar progresso para cópias recursivas com total agregado opcional
- reduzir alocações em hot paths (`ls`, `find`, `cp`)

## Prioridade P2 (Produto)

### 7) Empacotamento e release

- criar release workflow (tag -> build artifacts)
- publicar binários prebuilt (Linux/macOS)
- checksums e instruções de instalação por release

### 8) Configuração e extensibilidade

- estrutura de registry interna para novos subcomandos
- convenção de implementação para novos comandos
- guia de contribuição (`CONTRIBUTING.md`)

### 9) Documentação

- página de arquitetura (design decisions)
- tabela de compatibilidade com GNU coreutils (parcial)
- changelog versionado (`CHANGELOG.md`)

## Backlog de Comandos Futuros

- `ln`
- `stat`
- `which`
- `xargs`
- `sort`
- `uniq`
- `cut`
- `tr`
- `sed` (versão mínima)

## Critérios de Pronto por Funcionalidade

Cada novo comando/feature deve incluir:

- implementação do comando
- `--help` completo
- tratamento de erros amigável
- pelo menos 1 teste de integração no CI
- atualização de documentação (`README.md` + este roadmap, se necessário)
