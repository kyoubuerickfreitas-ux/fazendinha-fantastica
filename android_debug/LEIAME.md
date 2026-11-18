# Chave de TESTE (debug)

`debug.keystore` assina só os APKs de teste gerados pelo GitHub Actions (senha `android`, alias `androiddebugkey`).
Ela fica no repositório de propósito: com a mesma chave em todo build, o celular instala as versões novas
**por cima** da antiga, sem desinstalar e sem perder o save.

⚠️ Não use esta chave para a Play Store. A chave de upload de verdade vai ser guardada nos *Secrets* do GitHub.
