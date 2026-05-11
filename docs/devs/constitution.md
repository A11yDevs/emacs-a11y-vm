# Constituicao do Projeto emacs-a11y-vm (Devs)

Documento normativo para manutencao tecnica do projeto.

## Principios centrais

1. Acessibilidade primeiro
- Fluxo com sintese de voz funcional desde o boot e inegociavel.

2. QEMU-only
- Backend suportado: QEMU.
- Nao adicionar/reativar VirtualBox, VBoxManage, VDI ou vboxsf.

3. Dois discos qcow2
- Sistema: substituivel.
- Dados (/home): persistente.

4. Idempotencia
- Comandos e scripts devem ser seguros em reexecucao.

5. Release em qcow2
- Pipeline publica qcow2 e a CLI consome qcow2 diretamente.

6. Erro explicito
- Falhar cedo com mensagem orientativa.

7. Sem segredos
- Nao comitar credenciais reais/tokens/chaves.

8. Documentacao viva
- Toda mudanca funcional deve refletir em docs relevantes.

## Regras de implementacao

- Manter coerencia entre:
  - CLI host
  - scripts packer
  - servicos/scripts guest
  - workflow de release
  - documentacao de usuario e devs
- Preservar mecanismos de recuperacao de voz.
- Preservar disco de dados de usuario por padrao.

## Checklist de PR tecnico

- [ ] Continua QEMU-only?
- [ ] Continua acessivel no boot?
- [ ] Preserva /home em upgrades?
- [ ] Nao introduz segredo?
- [ ] Documentacao atualizada?
