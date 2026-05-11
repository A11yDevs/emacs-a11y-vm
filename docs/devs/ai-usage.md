# Declaracao de Uso de IA

Este documento descreve como IA pode ser usada no desenvolvimento do projeto emacs-a11y-vm, com transparencia e responsabilidade.

## 1. Ferramentas de IA utilizadas

As contribuicoes podem usar, entre outras:

- GitHub Copilot (autocomplete e chat)
- Agentes do Copilot no VS Code para tarefas de implementacao, revisao e documentacao

## 2. Modelos utilizados

No fluxo atual de assistencia tecnica deste projeto, o modelo principal utilizado no Copilot Chat e:

- GPT-5.3-Codex

Observacao:

- Outros modelos podem ser usados quando configurados no ambiente do mantenedor, mas toda contribuicao deve seguir as mesmas regras de revisao humana desta declaracao.

## 3. Escopo permitido de uso de IA

Uso recomendado:

- gerar rascunhos de codigo e scripts
- refatorar trechos repetitivos
- sugerir testes
- melhorar e manter documentacao tecnica
- apoiar investigacao de erros e troubleshooting

## 4. Escopo nao permitido sem revisao reforcada

Nao aceitar automaticamente respostas de IA para:

- mudancas de seguranca sem validacao manual
- alteracoes de arquitetura sem aprovacao de mantenedores
- qualquer acao que exponha segredos, tokens, chaves ou credenciais
- publicacao de conteudo sem verificacao de licenca e autoria

## 5. Revisao humana obrigatoria

Toda contribuicao assistida por IA deve ser revisada por humano antes de merge.

Checklist minimo de revisao:

- o comportamento esta correto no contexto do projeto
- a mudanca respeita a constituicao (QEMU-only, dois discos qcow2, acessibilidade)
- nao ha regressao de acessibilidade
- nao ha segredos no codigo, scripts ou docs
- a documentacao foi atualizada quando necessario

## 6. Rastreabilidade em PRs

Quando aplicavel, informar no PR:

- que houve uso de IA
- em quais arquivos/areas a IA ajudou
- quais validacoes manuais foram executadas

Exemplo curto para descricao de PR:

```text
Esta PR teve apoio de IA (GitHub Copilot/Agentes) para rascunho inicial.
Todas as alteracoes foram revisadas manualmente, testadas localmente e ajustadas conforme a constituicao do projeto.
```

## 7. Responsabilidade final

A responsabilidade pelo conteudo mergeado e sempre humana.
IA e ferramenta de apoio, nao autora autonoma das decisoes tecnicas do projeto.
