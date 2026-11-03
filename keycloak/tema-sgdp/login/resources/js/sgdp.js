// Tela de login do SGDP: mostrar e ocultar a senha, e o botão "Entrando..." ao enviar
// (evita o segundo envio, como o formulário do front).
(function () {
  "use strict";

  document.addEventListener("click", function (evento) {
    var botao = evento.target.closest("[data-mostrar-senha]");
    if (!botao) return;
    var campo = document.getElementById(botao.getAttribute("aria-controls"));
    if (!campo) return;
    var mostrar = campo.type === "password";
    campo.type = mostrar ? "text" : "password";
    botao.setAttribute("aria-pressed", mostrar ? "true" : "false");
    botao.setAttribute("aria-label", mostrar ? "Ocultar a senha" : "Mostrar a senha");
  });

  document.addEventListener("submit", function (evento) {
    var form = evento.target;
    var botao = form.querySelector("button[type=submit].botao-entrar");
    if (!botao) return;
    if (botao.getAttribute("aria-disabled") === "true") {
      evento.preventDefault();
      return;
    }
    botao.setAttribute("aria-disabled", "true");
    botao.classList.add("carregando");
  });

  // Voltar pelo histórico (cache do navegador) não pode deixar o botão preso em "Entrando..."
  window.addEventListener("pageshow", function () {
    document.querySelectorAll("button.botao-entrar.carregando").forEach(function (b) {
      b.classList.remove("carregando");
      b.removeAttribute("aria-disabled");
    });
  });
})();
