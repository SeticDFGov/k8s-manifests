<#import "template.ftl" as layout>
<#-- Tela de login: a mesma do /auth do front (e-mail e senha institucionais, com ícones e o
     botão de mostrar a senha). Sem cadastro, sem "esqueci a senha" e sem outros provedores:
     a conta e a senha são as da rede do GDF (AD). -->
<#assign erroCampo = messagesPerField.existsError('username','password')>
<@layout.registrationLayout displayMessage=!erroCampo; section>
  <#if section = "header">
    Entrar
  <#elseif section = "form">
    <#if erroCampo>
      <div class="aviso aviso-error" role="alert" id="input-error">
        <svg class="aviso-icone" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <p class="aviso-texto">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</p>
      </div>
    </#if>

    <#if realm.password>
      <form id="kc-form-login" action="${url.loginAction}" method="post" novalidate>
        <#if !usernameHidden??>
          <div class="campo-icone">
            <span class="icone-esquerda" aria-hidden="true">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </span>
            <input id="username" name="username" type="text" class="campo"
                   value="${(login.username!'')}"
                   placeholder="Email Institucional" aria-label="E-mail institucional"
                   autocomplete="username" autocapitalize="none" spellcheck="false" dir="ltr" autofocus
                   <#if erroCampo>aria-invalid="true" aria-describedby="input-error"</#if> />
          </div>
        </#if>

        <div class="campo-icone campo-senha">
          <span class="icone-esquerda" aria-hidden="true">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </span>
          <input id="password" name="password" type="password" class="campo"
                 placeholder="Senha Institucional" aria-label="Senha institucional"
                 autocomplete="current-password" dir="ltr"
                 <#if usernameHidden??>autofocus</#if>
                 <#if erroCampo>aria-invalid="true" aria-describedby="input-error"</#if> />
          <button type="button" class="botao-olho" data-mostrar-senha aria-controls="password"
                  aria-label="Mostrar a senha" aria-pressed="false">
            <svg class="olho-aberto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            <svg class="olho-fechado" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
            </svg>
          </button>
        </div>

        <#if realm.rememberMe && !usernameHidden??>
          <label class="lembrar">
            <input id="rememberMe" name="rememberMe" type="checkbox" <#if login.rememberMe??>checked</#if>>
            ${msg("rememberMe")}
          </label>
        </#if>

        <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
        <button id="kc-login" name="login" type="submit" class="botao botao-primario botao-bloco botao-entrar">
          <svg class="girando" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity=".25"></circle>
            <path fill="currentColor" opacity=".75" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="texto-entrar">Entrar</span>
          <span class="texto-entrando">Entrando...</span>
        </button>
      </form>
    </#if>
  </#if>
</@layout.registrationLayout>
