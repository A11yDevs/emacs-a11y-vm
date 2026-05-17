# ea11ctl (legado)

> **AVISO DE MIGRAÇÃO:** O `ea11ctl` foi migrado para o repositório **[A11yDevs/a11yctl](https://github.com/A11yDevs/a11yctl)** e renomeado para `a11yctl` a partir da versão **0.2.0**.
>
> Este diretório (`cli/`) e o comando `ea11ctl` **não receberão mais atualizações**.

## Como migrar

### Instalar o a11yctl

```powershell
irm https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.ps1 | iex
```

### Migrar VMs e configurações

Após instalar, execute:

```powershell
a11yctl migrate
```

O comando detecta `~/.emacs-a11y-vm` e copia VMs/configs para `~/.a11yctl`.  
O diretório antigo **nunca é removido automaticamente**.

### Compatibilidade

O novo pacote instala também um `ea11ctl` como alias de compatibilidade — automações existentes continuam funcionando, mas exibem um aviso de depreciação.

## Versão atual deste diretório

Última versão do `ea11ctl`: **0.2.0** (versão final — sem novas funcionalidades)

## Documentação

Consulte o README e a documentação do novo repositório:
<https://github.com/A11yDevs/a11yctl>
