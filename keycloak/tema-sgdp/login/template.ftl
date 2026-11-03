<#import "footer.ftl" as loginFooter>
<#-- Moldura de todas as telas de login: a mesma do /auth do front (fundo cinza, cartão branco
     com a marca do GDF). Os scripts do base (sessão aberta em outra aba, links de uso único)
     continuam, porque o fluxo de login depende deles. -->
<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="pt-BR">
<head>
    <meta charset="utf-8">
    <#if properties.meta?has_content>
        <#list properties.meta?split(' ') as meta>
            <meta name="${meta?split('==')[0]}" content="${meta?split('==')[1]}"/>
        </#list>
    </#if>
    <title>Entrar · SGDP</title>
    <link rel="icon" href="${url.resourcesPath}/img/favicon.ico" />
    <#if properties.styles?has_content>
        <#list properties.styles?split(' ') as style>
            <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
        </#list>
    </#if>
    <script type="importmap">
        {
            "imports": {
                "rfc4648": "${url.resourcesCommonPath}/vendor/rfc4648/rfc4648.js"
            }
        }
    </script>
    <#if scripts??>
        <#list scripts as script>
            <script src="${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <script type="module">
        import { startSessionPolling } from "${url.resourcesPath}/js/authChecker.js";
        startSessionPolling("${url.ssoLoginInOtherTabsUrl?no_esc}");
    </script>
    <script type="module">
        document.addEventListener("click", (event) => {
            const link = event.target.closest("a[data-once-link]");
            if (!link) return;
            if (link.getAttribute("aria-disabled") === "true") { event.preventDefault(); return; }
            link.setAttribute("role", "link");
            link.setAttribute("aria-disabled", "true");
        });
    </script>
    <#if authenticationSession??>
        <script type="module">
            import { checkAuthSession } from "${url.resourcesPath}/js/authChecker.js";
            checkAuthSession("${authenticationSession.authSessionIdHash}");
        </script>
    </#if>
    <script src="${url.resourcesPath}/js/sgdp.js" defer></script>
</head>

<body class="${bodyClass}" data-page-id="login-${pageId}">
<main id="conteudo" class="pagina">
  <div class="moldura">
    <div class="cartao">
      <div class="cartao-corpo">
        <div class="marca">
          <img src="${url.resourcesPath}/img/marca-gdf.png" alt="Logo GDF">
        </div>

        <h1 id="kc-page-title" class="titulo"><#nested "header"></h1>

        <#if auth?has_content && auth.showUsername() && !auth.showResetCredentials()>
          <p class="conta-atual">
            <span>${auth.attemptedUsername}</span>
            <a id="reset-login" href="${url.loginRestartFlowUrl}">Trocar de conta</a>
          </p>
        </#if>

        <#-- Avisos que não são de um campo (sessão expirada, conta desativada...). Ações
             pedidas pelo próprio aplicativo não mostram o aviso de "conclua a ação". -->
        <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
          <div class="aviso aviso-${message.type}" role="alert">
            <svg class="aviso-icone" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <#if message.type = 'success'>
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
              <#else>
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </#if>
            </svg>
            <p class="aviso-texto">${kcSanitize(message.summary)?no_esc}</p>
          </div>
        </#if>

        <#nested "form">

        <#if auth?has_content && auth.showTryAnotherWayLink()>
          <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post">
            <input type="hidden" name="tryAnotherWay" value="on"/>
            <button type="submit" class="link">${msg("doTryAnotherWay")}</button>
          </form>
        </#if>

        <#if displayInfo>
          <div id="kc-info" class="info"><#nested "info"></div>
        </#if>

        <@loginFooter.content/>
      </div>
    </div>
  </div>
</main>
</body>
</html>
</#macro>
