# Constituicao do Projeto emacs-a11y-vm

Este documento registra os principios fundamentais que guiam as decisoes de design e implementacao do projeto.

---

## 1. Acessibilidade e prioridade absoluta

A VM existe para tornar o Emacs acessivel via sintese de voz. Toda mudanca deve preservar:

- speakup/espeakup funcionando no boot
- fluxo de recuperacao de voz (atalhos/comandos de emergencia)
- operacao sem interface grafica obrigatoria

---

## 2. Projeto QEMU-only

O projeto adota QEMU como unico backend de virtualizacao para fluxo suportado.

- Nao introduzir dependencias de VirtualBox, VBoxManage, VDI ou vboxsf.
- Nao criar novos fluxos paralelos de backend.
- Documentacao, scripts e CI devem refletir esse direcionamento.

---

## 3. Arquitetura de dois discos (qcow2) e inviolavel

A separacao entre sistema e dados do usuario e obrigatoria:

- Disco de sistema (qcow2): atualizado/substituido em upgrades.
- Disco de dados (qcow2): persistente, montado em /home e preservado.

Qualquer mudanca que misture esses papeis viola a arquitetura do projeto.

---

## 4. Customizacoes do usuario em /home

Customizacoes de usuario devem viver em /home.

- O usuario deve conseguir atualizar a imagem de sistema sem perder dados.
- Scripts e documentacao nao devem incentivar alteracoes persistentes fora de /home.

---

## 5. Idempotencia da CLI e dos scripts

Comandos principais devem ser reexecutaveis com seguranca.

- vm install: nao deve baixar novamente sem necessidade (exceto force-download).
- vm start/stop/status/ssh: devem lidar com estado existente sem corromper ambiente.
- Disco de dados: jamais sobrescrever por padrao.

---

## 6. Distribuicao de release em QCOW2

A distribuicao oficial e baseada em asset qcow2 no GitHub Releases.

- CI publica qcow2.
- CLI prepara/consome qcow2 diretamente.
- Nao converter para formatos legados no fluxo suportado.

---

## 7. Build reproduzivel via Packer + QEMU

A imagem base e definida por:

- packer/debian-a11y.pkr.hcl
- packer/http/preseed.cfg
- arquivos em packer/files

Esses artefatos sao a fonte de verdade para sistema base.

---

## 8. Erros devem ser fatais e informativos

Scripts de automacao devem falhar cedo com contexto claro.

- Evitar suprimir erro silenciosamente.
- Mensagens devem indicar acao de recuperacao quando possivel.

---

## 9. Sem dados sensiveis em codigo/documentacao

Nao incluir:

- tokens
- chaves privadas
- credenciais reais

Valores de laboratorio da VM devem estar claramente identificados como nao-producao.

---

## 10. Documentacao acompanha mudancas

Toda alteracao funcional relevante deve atualizar a documentacao correspondente.

- arquitetura
- releases
- instalacao/upgrade
- operacao e troubleshooting

---

## 11. Recuperacao de emergencia de voz e obrigatoria

Mudancas em espeakup/speakup/dotfiles/systemd nao podem remover os mecanismos de recuperacao de audio para usuarios cegos.

---

## Checklist para modificacoes

Antes de consolidar mudancas significativas, validar:

- [ ] acessibilidade continua funcional no boot e pos-boot
- [ ] backend segue QEMU-only
- [ ] disco de dados em /home permanece preservado
- [ ] comandos sao idempotentes
- [ ] documentacao foi atualizada
- [ ] nenhum segredo foi introduzido
