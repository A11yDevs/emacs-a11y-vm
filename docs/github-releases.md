# Distribuição e releases no GitHub

Este documento complementa o README e explica como a distribuição da VM acontece no repositório, como os releases são publicados no GitHub e qual é o papel das pastas `.github` e `packer` nesse fluxo.

## Visão geral do fluxo

A distribuição da VM é baseada em um pipeline de CI/CD no GitHub Actions:

1. O workflow de release é disparado.
2. O workflow monta automaticamente a imagem Debian acessível com Packer + QEMU.
3. A imagem gerada (`.qcow2`) é convertida para `.vmdk`.
4. Os artefatos são publicados em um GitHub Release.
5. O usuário final pode baixar os discos manualmente ou usar `scripts/install-release-vm.ps1` (Windows) para instalar no VirtualBox.

Arquivo principal do pipeline:

- `.github/workflows/release.yml`

## Quando um release é gerado

O workflow aceita dois modos de execução:

1. Execução por tag (`push` de tags `v*`)
2. Execução manual (`workflow_dispatch`)

### 1. Release por tag (fluxo oficial)

Quando uma tag no formato `vX.Y.Z` é enviada para o repositório, o workflow publica um release normal (não pré-release).

Exemplo:

```bash
git tag v1.2.0
git push origin v1.2.0
```

### 2. Execução manual (fluxo de teste)

Também é possível disparar o workflow manualmente na aba Actions. Nesse caso, ele gera uma tag de desenvolvimento no formato `dev-YYYYMMDD-HHMMSS` e publica como pré-release por padrão.

Isso é útil para validar o build antes de criar uma versão oficial.

## O que a pasta .github tem a ver com isso

A pasta `.github` guarda as automações do GitHub Actions.

Neste projeto, o arquivo `.github/workflows/release.yml` define todo o processo de build e publicação, incluindo:

- checkout do código
- preparação do runner (KVM + dependências)
- cache e download da ISO Debian
- execução do Packer
- conversão/compactação de discos
- criação do release e upload dos arquivos

Sem esse workflow, não existe release automatizado.

## O que a pasta packer tem a ver com isso

A pasta `packer` define como a VM é construída.

Arquivos principais:

- `packer/debian-a11y.pkr.hcl`: template de build do Packer (QEMU)
- `packer/http/preseed.cfg`: instalação desassistida do Debian (preseed)

Em termos práticos:

1. O workflow chama `packer init` e `packer build` usando `packer/debian-a11y.pkr.hcl`.
2. O template sobe a instalação do Debian com QEMU e usa `packer/http/preseed.cfg` para automatizar a instalação.
3. O resultado do build é um disco `qcow2` com Debian acessível configurado.

Ou seja, `packer` é a receita da imagem. `.github` é a orquestração para executar a receita e publicar o resultado.

## Artefatos publicados no release

O workflow publica os seguintes arquivos:

- `debian-a11ydevs.qcow2` (QEMU/KVM/libvirt)
- `debian-a11ydevs.vmdk` (VirtualBox)

Esses arquivos são gerados no CI e enviados automaticamente para o GitHub Release.

## Como o script install-release-vm.ps1 se conecta ao release

O script `scripts/install-release-vm.ps1` consome exatamente os releases gerados por esse pipeline:

1. consulta a API de releases do GitHub
2. encontra o asset `.vmdk`
3. baixa o disco
4. cria e configura uma VM no VirtualBox

Isso fecha o ciclo de distribuição: o CI publica o artefato e o script instala o artefato no ambiente do usuário.

## Variáveis de repositório que afetam o build

No workflow atual, duas variáveis opcionais podem influenciar a execução:

- `DEBIAN_ISO_URL`: URL da ISO Debian usada no build
- `DEBIAN_ISO_CACHE_KEY`: chave de cache para a ISO no Actions

Se não forem definidas, o workflow usa os valores padrão configurados no próprio `release.yml`.

## Boas práticas para lançar versões

1. Validar um pré-release manual após mudanças em `packer` ou no workflow.
2. Criar tag semântica (`vX.Y.Z`) somente quando o build estiver estável.
3. Testar o `.vmdk` publicado com `scripts/install-release-vm.ps1` antes de anunciar.
4. Manter este documento e o README atualizados quando o fluxo de release mudar.
