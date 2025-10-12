# Firebase Package Name Update Guide

## 📦 Novo Package Name

Mudamos o package name do app de:
```
com.example.flutter_multiplatform_app  →  com.tcs.pace_scheduler
```

## ⚠️ Ação Necessária no Firebase Console

O arquivo `google-services.json` local foi atualizado temporariamente para permitir builds, mas você deve **adicionar o novo package name no Firebase Console** para que o FCM (notificações push) funcione corretamente em produção.

## 🔧 Como Atualizar no Firebase Console

### Opção 1: Adicionar Novo Package ao App Existente (Recomendado)

1. **Acesse o Firebase Console:**
   - Vá para: https://console.firebase.google.com
   - Selecione o projeto: **tcs-paceport-scheduler**

2. **Adicione o novo package:**
   - No menu lateral, clique em **⚙️ Project Settings**
   - Vá para a aba **General**
   - Na seção **Your apps**, encontre o app Android
   - Clique em **Add package name**
   - Digite: `com.tcs.pace_scheduler`
   - Clique em **Add**

3. **Baixe o novo google-services.json:**
   - Depois de adicionar, clique em **Download google-services.json**
   - Substitua o arquivo em: `android/app/google-services.json`

### Opção 2: Criar Novo App Android (Alternativa)

Se preferir ter um app separado:

1. **Adicione um novo app Android:**
   - No Firebase Console, clique em **Add app** → **Android**
   - Package name: `com.tcs.pace_scheduler`
   - App nickname: `TCS Pace Scheduler`
   - Debug signing certificate SHA-1: (opcional, para Google Sign-In)

2. **Configure o app:**
   - Baixe o `google-services.json`
   - Substitua em: `android/app/google-services.json`
   - Configure Cloud Messaging se necessário

3. **Migre configurações:**
   - Cloud Messaging (FCM)
   - App Check
   - Analytics
   - Etc.

## 📝 Status Atual

✅ **Arquivo local atualizado:**
```json
{
  "android_client_info": {
    "package_name": "com.tcs.pace_scheduler"
  }
}
```

⚠️ **Firebase Console:** Ainda precisa ser atualizado com o novo package

## 🔐 Segurança

O arquivo `google-services.json` agora está no `.gitignore` por conter chaves de API sensíveis.

**Para novos desenvolvedores:**
1. Solicite o arquivo `google-services.json` ao administrador do projeto
2. Coloque em: `android/app/google-services.json`
3. Nunca faça commit deste arquivo

## 🧪 Como Testar

Após atualizar o Firebase Console:

```bash
# 1. Build debug
flutter run -d <device-id>

# 2. Teste notificações push
# - Com app aberto (deve usar WebSocket)
# - Com app fechado (deve usar FCM)

# 3. Build release
flutter build apk --release
```

## 📱 APPs Afetados

| Ambiente | Package Name | Status |
|----------|--------------|--------|
| Antigo | `com.example.flutter_multiplatform_app` | ⚠️ Deprecado |
| Novo | `com.tcs.pace_scheduler` | ✅ Atual |

## 🔗 Links Úteis

- Firebase Console: https://console.firebase.google.com
- Projeto Firebase: https://console.firebase.google.com/project/tcs-paceport-scheduler
- Documentação: https://firebase.google.com/docs/android/setup

## ❓ FAQ

**Q: Por que mudar o package name?**
A: O package `com.example.*` é genérico e não deve ser usado em produção. O novo package `com.tcs.pace_scheduler` reflete corretamente o projeto.

**Q: O app antigo vai parar de funcionar?**
A: Sim, se você desinstalar o app antigo (`com.example.flutter_multiplatform_app`) e instalar o novo (`com.tcs.pace_scheduler`), eles serão tratados como apps diferentes pelo Android.

**Q: Preciso fazer algo com os tokens FCM existentes?**
A: Sim, os tokens FCM do package antigo não funcionarão com o novo package. Usuários precisarão reinstalar o app para receber novos tokens.

**Q: Como migrar usuários do app antigo?**
A:
1. Publique o novo app na Play Store com o novo package name
2. Informe usuários sobre a atualização
3. Desinstale o app antigo antes de instalar o novo (ou use o Firebase App Distribution para testes)

## 🚀 Próximos Passos

1. ✅ Atualizar Firebase Console com novo package
2. ✅ Testar FCM com novo package
3. ✅ Atualizar Firebase App Distribution (se usado)
4. ✅ Atualizar documentação do projeto
5. ✅ Informar equipe sobre mudança de package

---

**Última atualização:** $(date -Iseconds)
**Versão do app:** 1.0.1+2
