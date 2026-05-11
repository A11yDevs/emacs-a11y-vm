# Guia de upgrade (QEMU-only)

Este documento foi simplificado para o fluxo atual.

Use como referencia principal:

- docs/user/upgrade.md

Resumo rapido:

1. pare a VM:

```bash
ea11ctl vm stop
```

2. atualize a imagem de sistema (qcow2) mantendo o disco de dados

3. inicie novamente:

```bash
ea11ctl vm start
```

Invariantes do upgrade:

- sistema atualiza
- /home permanece preservado no disco de dados qcow2
- nao ha conversao para formatos de VirtualBox no fluxo suportado
