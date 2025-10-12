# Firebase Package Name Update Guide

## 📦 Novo Package Name

Mudamos o package name do app de:
```
com.example.flutter_multiplatform_app  →  com.tcs.pace_scheduler
```

## ⚠️ Ação Necessária no Firebase Console

O arquivo `google-services.json` local foi atualizado temporariamente para permitir builds, mas você **DEVE adicionar um novo app Android** no Firebase Console para que o FCM (notificações push) funcione corretamente em produção.

## 🔧 Como Adicionar Novo App Android no Firebase

⚠️ **IMPORTANTE:** O Firebase **NÃO permite editar** o package name de um app existente. Você deve criar um **novo app Android**.

### Passo a Passo (5 minutos):

1. **Acesse o Firebase Console:**
   ```
   https://console.firebase.google.com/project/tcs-paceport-scheduler
   ```

2. **Adicione um novo app Android:**
   - Na página inicial do projeto, clique em **"Add app"** (ou ícone **Android**)
   - Ou vá em: **Project Settings** → **General** → Scroll down → **Add app** → **Android**

3. **Configure o novo app:**

   **Passo 1: Register app**
   - **Android package name:** `com.tcs.pace_scheduler` ✅
   - **App nickname (optional):** `TCS Pace Scheduler` (recomendado)
   - **Debug signing certificate SHA-1 (optional):** Deixe em branco por enquanto
   - Clique em **Register app**

   **Passo 2: Download config file**
   - Clique em **Download google-services.json**
   - **IMPORTANTE:** Salve este arquivo!
   - Clique em **Next**

   **Passo 3: Add Firebase SDK**
   - Pode pular esta etapa (já configurado)
   - Clique em **Next**

   **Passo 4: Run your app**
   - Clique em **Continue to console**

4. **Substitua o arquivo local:**
   ```bash
   # Substitua o arquivo baixado em:
   cp ~/Downloads/google-services.json android/app/google-services.json
   ```

5. **Configure Cloud Messaging (FCM):**
   - No Firebase Console, vá em: **Build** → **Cloud Messaging**
   - Se solicitado, configure o **Cloud Messaging API** (habilitado por padrão)

### ✅ Pronto! Agora você pode rodar o app:

```bash
# Limpar build anterior
flutter clean

# Rodar no dispositivo
flutter run -d 192.168.15.28:42493

# Ou build release
flutter build apk --release
```

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
