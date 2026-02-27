# zigbox

Coreutils leve estilo Busybox, escrito 100% em Zig, com subcomandos modernos (sem symlink por comando).

## Requisitos

- Zig `0.15.2+`
- Linux/macOS/Windows (testado localmente em Linux)

## Stack

- Linguagem: Zig
- Parser de argumentos: `zig-clap 0.11.0`
- Alocação: `GeneralPurposeAllocator` no root + `ArenaAllocator` por subcomando
- Saída colorida ANSI (quando `stdout` é TTY e `NO_COLOR` não está definido)

## Estrutura

```text
zigbox/
├── build.zig
├── build.zig.zon
└── src/
    ├── main.zig
    ├── common.zig
    ├── ls.zig
    ├── rm.zig
    ├── find.zig
    └── grep.zig
```

## Inicialização do projeto (do zero)

```bash
zig init-exe
zig fetch --save https://github.com/Hejsil/zig-clap/archive/refs/tags/0.11.0.tar.gz
```

Depois, ajuste o `build.zig` para importar o módulo `clap` e use `build.zig.zon` com a dependency registrada pelo `zig fetch --save`.

## Build

### Debug

```bash
zig build
```

### ReleaseFast

```bash
zig build -Doptimize=ReleaseFast
```

## Execução

```bash
zig build run -- <subcomando> [flags] [args]
```

Exemplo:

```bash
zig build run -- ls -la .
```

## Comandos disponíveis

### 1) `ls`

Lista conteúdo de diretório.

Uso:

```bash
zigbox ls [flags] [path]
```

Flags:

- `-a`, `--all`: inclui arquivos ocultos
- `-l`, `--long`: formato longo
- `-h`, `--human-readable`: tamanho amigável (com `-l`)
- `--help`: ajuda do comando

Observações:

- Ordenação básica por nome (case-insensitive)
- Cores:
  - diretórios: azul
  - executáveis: verde
  - symlinks: ciano

### 2) `rm`

Remove arquivos e diretórios.

Uso:

```bash
zigbox rm [flags] <path>...
```

Flags:

- `-f`, `--force`: ignora inexistentes e não interrompe
- `-r`, `--recursive`: remove diretórios recursivamente
- `-i`, `--interactive`: pede confirmação simples
- `--help`: ajuda do comando

### 3) `find`

Busca arquivos/diretórios com filtros simples.

Uso:

```bash
zigbox find [flags] [path]
```

Flags:

- `-name <pattern>` ou `--name <pattern>`: filtro por nome (`*` e `?`)
- `-type <f|d|l>` ou `--type <f|d|l>`: tipo (arquivo, diretório, symlink)
- `--help`: ajuda do comando

Exemplo:

```bash
zigbox find . -name "*.zig" -type f
```

### 4) `grep`

Busca string em arquivos.

Uso:

```bash
zigbox grep [flags] <pattern> <path>...
```

Flags:

- `-r`, `--recursive`: recursivo em diretórios
- `--help`: ajuda do comando

Exemplo:

```bash
zigbox grep -r "TODO" src
```

## Ajuda

Ajuda global:

```bash
zigbox --help
```

Ajuda por comando:

```bash
zigbox ls --help
zigbox rm --help
zigbox find --help
zigbox grep --help
```

## Instalação global (opcional)

Após build:

```bash
zig build -Doptimize=ReleaseFast
```

Crie um symlink para um diretório no `PATH`:

```bash
sudo ln -sf "$(pwd)/zig-out/bin/zigbox" /usr/local/bin/zigbox
```

Verifique:

```bash
zigbox --help
```

## Extensibilidade

Para adicionar novos subcomandos (`cat`, `mkdir`, `tree`, `du`):

1. Criar `src/<cmd>.zig` com função pública:

```zig
pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void
```

2. Importar no `src/main.zig`.
3. Adicionar branch de dispatch no `main.zig`.
4. Implementar `--help` próprio no novo comando.

## Erros e UX

- Mensagens amigáveis no stderr
- Retorno de erro quando necessário (`anyerror`)
- `error.InvalidArgs` para argumentos inválidos e fluxo de ajuda

## Estado atual

- Compila com sucesso em Zig `0.15.2`
- Binário gerado em: `zig-out/bin/zigbox`
