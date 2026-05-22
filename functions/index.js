const admin = require("firebase-admin");

const { onSchedule } = require("firebase-functions/v2/scheduler");

const { onCall, HttpsError } = require("firebase-functions/v2/https");

admin.initializeApp();

function hojeISO() {
  const hoje = new Date();
  return hoje.toISOString().slice(0, 10);
}

async function atualizarUsuarioAssinatura(userId, status, planoNome) {
  await admin
    .firestore()
    .collection("usuarios")
    .doc(userId)
    .set(
      {
        assinaturaAtiva:
          status === "ativa" || status === "cancelamento_agendado",
        assinaturaStatus: status,
        plano: planoNome || "",
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

const { onDocumentCreated } = require("firebase-functions/v2/firestore");

exports.enviarPushNotificacao = onDocumentCreated(
  "notificacoes/{notificacaoId}",
  async (event) => {
    try {
      const dados = event.data.data();
      const userId = dados.userId;

      if (!userId) return;

      let tokens = [];

      // 🔥 CASO ADMIN
      if (userId === "admin") {
        const admins = await admin
          .firestore()
          .collection("usuarios")
          .where("tipo", "==", "admin")
          .get();

        admins.forEach((doc) => {
          const t = doc.data().fcmTokens || [];
          tokens.push(...t);
        });
      } else {
        // 🔥 CASO CLIENTE
        const userDoc = await admin
          .firestore()
          .collection("usuarios")
          .doc(userId)
          .get();

        if (!userDoc.exists) return;

        tokens = userDoc.data()?.fcmTokens || [];
      }

      tokens = [...new Set(tokens)].filter(Boolean);

      if (!tokens.length) {
        console.log("Nenhum token encontrado");
        return;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: dados.titulo || "Notificação",
          body: dados.mensagem || "",
        },
        data: {
          tela: "notificacoes",
          userId: String(userId),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "default",
            sound: "default",
          },
        },
      });

      console.log(
        "Push enviado:",
        response.successCount,
        "falhas:",
        response.failureCount,
      );
    } catch (error) {
      console.error("Erro ao enviar push:", error);
    }
  },
);
exports.criarAgendamento = onCall(async (request) => {
  const userId = request.auth?.uid;
  const dados = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const { servico, servicoId, barbeiro, barbeiroId, data, horario, preco } =
    dados;

  const precoServico = Number(preco || 0);

  if (!Number.isFinite(precoServico) || precoServico <= 0) {
    throw new HttpsError("invalid-argument", "Preço do serviço inválido.");
  }

  if (!servico || !servicoId || !barbeiro || !barbeiroId || !data || !horario) {
    throw new HttpsError("invalid-argument", "Dados incompletos.");
  }

  try {
    const db = admin.firestore();

    const dataBase = new Date(data);

    const ano = dataBase.getFullYear();
    const mes = String(dataBase.getMonth() + 1).padStart(2, "0");
    const dia = String(dataBase.getDate()).padStart(2, "0");

    const dataDia = `${ano}-${mes}-${dia}`;

    // força horário Brasil UTC-3
    const dataHora = new Date(`${ano}-${mes}-${dia}T${horario}:00-03:00`);

    if (dataHora.getTime() <= Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "Não é possível agendar em data ou horário passado.",
      );
    }

    const horarioId = horario.replace(":", "h");
    const bloqueioId = `${barbeiroId}_${dataDia}_${horarioId}`;

    const bloqueioRef = db.collection("bloqueios_agendamentos").doc(bloqueioId);
    const agendamentoRef = db.collection("agendamentos").doc();

    const conflitoCliente = await db
      .collection("agendamentos")
      .where("userId", "==", userId)
      .where("dataDia", "==", dataDia)
      .where("hora", "==", horario)
      .where("status", "==", "agendado")
      .limit(1)
      .get();

    if (!conflitoCliente.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Você já tem um agendamento neste dia e horário. Escolha outro horário.",
      );
    }

    const conflitoBarbeiroDia = await db
      .collection("agendamentos")
      .where("userId", "==", userId)
      .where("barbeiroId", "==", barbeiroId)
      .where("dataDia", "==", dataDia)
      .where("status", "==", "agendado")
      .limit(1)
      .get();

    if (!conflitoBarbeiroDia.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Você já tem um agendamento com esse barbeiro nesse dia. Escolha outro barbeiro.",
      );
    }

    const userDoc = await db.collection("usuarios").doc(userId).get();
    const nomeCliente = userDoc.data()?.nome?.trim() || "Cliente";

    await db.runTransaction(async (transaction) => {
      const bloqueioSnap = await transaction.get(bloqueioRef);

      if (bloqueioSnap.exists) {
        throw new HttpsError(
          "already-exists",
          "Esse horário acabou de ser ocupado. Escolha outro horário.",
        );
      }

      transaction.set(bloqueioRef, {
        agendamentoId: agendamentoRef.id,
        barbeiroId,
        dataDia,
        hora: horario,
        userId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(agendamentoRef, {
        cliente: nomeCliente,
        userId,
        servico,
        servicoId,
        preco: precoServico,
        barbeiro,
        barbeiroId,
        data: admin.firestore.Timestamp.fromDate(dataHora),
        dataHora: admin.firestore.Timestamp.fromDate(dataHora),
        dataDia,
        hora: horario,
        status: "agendado",
        bloqueioId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const dataFormatada = dataDia.split("-").reverse().join("/");

    await db.collection("notificacoes").add({
      userId: "admin",
      tipo: "novo_agendamento",
      destino: "agendamentos_admin",
      referenciaId: agendamentoRef.id,
      titulo: "Novo agendamento",
      mensagem:
        `${nomeCliente} agendou com ${barbeiro} ` +
        `no dia ${dataFormatada} às ${horario}.`,
      dataAgendamento: dataDia,
      horaAgendamento: horario,
      lida: false,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: "Agendamento feito com sucesso" };
  } catch (error) {
    console.error("ERRO CRIAR AGENDAMENTO:", error);

    if (error instanceof HttpsError) throw error;

    throw new HttpsError("internal", "Erro ao criar agendamento.");
  }
});
async function verificarAdmin(userId) {
  const doc = await admin.firestore().collection("usuarios").doc(userId).get();

  if (!doc.exists || doc.data()?.tipo !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Apenas o administrador pode fazer essa ação.",
    );
  }

  return doc.data()?.nome || "Admin";
}

exports.atualizarStatusAgendamentoAdmin = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { agendamentoId, acao } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!agendamentoId || !acao) {
    throw new HttpsError("invalid-argument", "Dados incompletos.");
  }

  if (!["cancelado", "concluido", "nao_compareceu"].includes(acao)) {
    throw new HttpsError("invalid-argument", "Ação inválida.");
  }

  const nomeAdmin = await verificarAdmin(userId);
  const db = admin.firestore();

  const ref = db.collection("agendamentos").doc(agendamentoId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Agendamento não encontrado.");
  }

  const dados = snap.data();

  if (dados.status !== "agendado") {
    throw new HttpsError(
      "failed-precondition",
      "Esse agendamento não está mais agendado.",
    );
  }

  const update = {
    status: acao,
    marcadoPor: nomeAdmin,
    acaoAdmin: acao,
    acaoAdminPor: nomeAdmin,
    acaoAdminEm: admin.firestore.FieldValue.serverTimestamp(),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (acao === "cancelado") {
    update.canceladoPor = "admin";
    update.canceladoPorNome = nomeAdmin;
    update.canceladoEm = admin.firestore.FieldValue.serverTimestamp();
  }

  if (acao === "concluido") {
    update.concluidoEm = admin.firestore.FieldValue.serverTimestamp();
  }

  if (acao === "nao_compareceu") {
    update.naoCompareceuEm = admin.firestore.FieldValue.serverTimestamp();
  }
  if (acao === "concluido" || acao === "nao_compareceu") {
    const dataHora = dados.dataHora?.toDate ? dados.dataHora.toDate() : null;

    if (!dataHora) {
      throw new HttpsError(
        "failed-precondition",
        "Data do agendamento inválida.",
      );
    }

    const liberarEm = new Date(dataHora.getTime() + 15 * 60 * 1000);

    if (new Date() < liberarEm) {
      throw new HttpsError(
        "failed-precondition",
        "Essa ação só pode ser feita 15 minutos após o horário agendado.",
      );
    }
  }
  await ref.update(update);
  if (acao === "cancelado" && dados.bloqueioId) {
    await db
      .collection("bloqueios_agendamentos")
      .doc(dados.bloqueioId)
      .delete();
  }
  if (acao === "cancelado" && dados.userId) {
    const dataCancelamento = (dados.dataDia || "")
      .split("-")
      .reverse()
      .join("/");

    await db.collection("notificacoes").add({
      userId: dados.userId,
      tipo: "admin_cancelou",
      destino: "agendamentos_cliente",
      referenciaId: agendamentoId,
      titulo: "Agendamento cancelado",

      mensagem:
        `Seu agendamento com ${dados.barbeiro || ""} ` +
        `no dia ${dataCancelamento} às ${dados.hora || ""} ` +
        `foi cancelado pelo estabelecimento.`,

      dataAgendamento: dados.dataDia || "",
      horaAgendamento: dados.hora || "",
      lida: false,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return {
    success: true,
    message: "Agendamento atualizado com sucesso.",
  };
});

exports.atualizarTempoServidor = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    await admin.firestore().collection("controle_tempo").doc("agora").set(
      {
        dataHora: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  },
);

exports.solicitarAssinaturaPagBank = onCall(async (request) => {
  const userId = request.auth?.uid;
  const dados = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  const { planoId, planoNome, planoDescricao, planoPreco, linkPagamento } =
    dados;

  if (!planoId || !planoNome || !planoPreco || !linkPagamento) {
    throw new HttpsError("invalid-argument", "Dados do plano incompletos.");
  }

  const db = admin.firestore();

  const assinaturaAtiva = await db
    .collection("assinaturas_planos")
    .where("userId", "==", userId)
    .where("status", "in", [
      "ativa",
      "cancelamento_agendado",
      "aguardando_confirmacao",
      "aguardando_aprovacao_admin",
    ])
    .limit(1)
    .get();

  if (!assinaturaAtiva.empty) {
    throw new HttpsError(
      "failed-precondition",
      "Você já possui uma assinatura ativa ou em análise.",
    );
  }

  const userDoc = await db.collection("usuarios").doc(userId).get();
  const userData = userDoc.data() || {};

  const docRef = await db.collection("assinaturas_planos").add({
    userId,
    cliente: userData.nome || request.auth.token.name || "Cliente",
    email: userData.email || request.auth.token.email || "",

    planoId,
    planoNome,
    planoDescricao: planoDescricao || "",
    planoPreco: Number(planoPreco),
    periodo: "mensal",

    gateway: "pagbank",
    metodoPagamento: "link_pagbank",
    linkPagamento,

    status: "aguardando_confirmacao",
    pagamentoStatus: "aguardando_pagamento",
    planoAtivoNoMomento: false,

    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    assinaturaDocId: docRef.id,
    checkoutUrl: linkPagamento,
    message: "Solicitação criada com sucesso.",
  };
});

exports.ativarAssinaturaPagBankAdmin = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { assinaturaId } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  await verificarAdmin(userId);

  if (!assinaturaId) {
    throw new HttpsError("invalid-argument", "Assinatura inválida.");
  }

  const db = admin.firestore();
  const ref = db.collection("assinaturas_planos").doc(assinaturaId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Assinatura não encontrada.");
  }

  const assinatura = snap.data();

  if (assinatura.status !== "aguardando_aprovacao_admin") {
    throw new HttpsError(
      "failed-precondition",
      "Essa assinatura não está aguardando aprovação.",
    );
  }

  const hoje = new Date();
  const proxima = new Date(hoje);
  proxima.setMonth(proxima.getMonth() + 1);

  const proximaTexto = proxima.toISOString().slice(0, 10);

  await ref.set(
    {
      status: "ativa",
      pagamentoStatus: "aprovado",
      planoAtivoNoMomento: true,
      notificacaoRenovacaoEnviada: false,
      notificacaoCancelamentoEnviada: false,
      ativadoEm: admin.firestore.FieldValue.serverTimestamp(),
      proximaCobrancaTexto: proximaTexto,
      beneficioAteTexto: proximaTexto,
      proximaCobrancaEm: admin.firestore.Timestamp.fromDate(proxima),
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await atualizarUsuarioAssinatura(
    assinatura.userId,
    "ativa",
    assinatura.planoNome,
  );

  await db.collection("notificacoes").add({
    userId: assinatura.userId,
    tipo: "assinatura_ativa",
    destino: "assinaturas_cliente",
    referenciaId: assinaturaId,
    titulo: "Assinatura ativada",
    mensagem: `Seu plano ${assinatura.planoNome || ""} foi ativado com sucesso.`,
    lida: false,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: "Assinatura ativada com sucesso.",
  };
});

exports.cancelarAssinaturaPagBankCliente = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { assinaturaId } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!assinaturaId) {
    throw new HttpsError("invalid-argument", "Assinatura inválida.");
  }

  const db = admin.firestore();
  const ref = db.collection("assinaturas_planos").doc(assinaturaId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Assinatura não encontrada.");
  }

  const assinatura = snap.data();

  if (assinatura.userId !== userId) {
    throw new HttpsError(
      "permission-denied",
      "Você não tem permissão para cancelar esta assinatura.",
    );
  }

  if (assinatura.status !== "ativa") {
    throw new HttpsError(
      "failed-precondition",
      "Somente assinaturas ativas podem ser canceladas.",
    );
  }

  await ref.set(
    {
      status: "cancelamento_agendado",
      pagamentoStatus: "cancelamento_agendado",
      planoAtivoNoMomento: true,
      renovacaoCancelada: true,
      canceladoEm: admin.firestore.FieldValue.serverTimestamp(),
      canceladoPor: "cliente",
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await atualizarUsuarioAssinatura(
    userId,
    "cancelamento_agendado",
    assinatura.planoNome,
  );

  await db.collection("notificacoes").add({
    userId: "admin",
    tipo: "cancelamento_agendado",
    destino: "assinaturas_admin",
    referenciaId: assinaturaId,
    titulo: "Cancelamento agendado",
    mensagem: `${assinatura.cliente || "Cliente"} agendou o cancelamento do plano ${assinatura.planoNome || ""}.`,
    lida: false,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

exports.reativarAssinaturaPagBankCliente = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { assinaturaId } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!assinaturaId) {
    throw new HttpsError("invalid-argument", "Assinatura inválida.");
  }

  const db = admin.firestore();
  const ref = db.collection("assinaturas_planos").doc(assinaturaId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Assinatura não encontrada.");
  }

  const assinatura = snap.data();

  if (assinatura.userId !== userId) {
    throw new HttpsError(
      "permission-denied",
      "Você não tem permissão para reativar esta assinatura.",
    );
  }

  if (assinatura.status !== "cancelamento_agendado") {
    throw new HttpsError(
      "failed-precondition",
      "Esta assinatura não está com cancelamento agendado.",
    );
  }

  await ref.set(
    {
      status: "ativa",
      pagamentoStatus: "aprovado",
      planoAtivoNoMomento: true,
      renovacaoCancelada: false,
      canceladoEm: null,
      canceladoPor: null,
      reativadoEm: admin.firestore.FieldValue.serverTimestamp(),
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await atualizarUsuarioAssinatura(userId, "ativa", assinatura.planoNome);

  await db.collection("notificacoes").add({
    userId: "admin",
    tipo: "assinatura_ativa",
    destino: "assinaturas_admin",
    referenciaId: assinaturaId,
    titulo: "Assinatura reativada",
    mensagem: `${assinatura.cliente || "Cliente"} reativou o plano ${assinatura.planoNome || ""}.`,
    lida: false,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

exports.verificarAssinaturasPagBank = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "America/Sao_Paulo",
  },
  async () => {
    const db = admin.firestore();

    const hoje = new Date();

    const hojeTexto = hoje.toISOString().slice(0, 10);

    // =========================
    // ASSINATURAS
    // =========================
    const snapshot = await db
      .collection("assinaturas_planos")
      .where("status", "in", ["ativa", "cancelamento_agendado"])
      .get();

    for (const doc of snapshot.docs) {
      const assinatura = doc.data();

      const beneficioAte =
        assinatura.beneficioAteTexto || assinatura.proximaCobrancaTexto || "";

      if (!beneficioAte) continue;

      const dataFim = new Date(`${beneficioAte}T00:00:00-03:00`);

      const diffDias = Math.ceil(
        (dataFim.getTime() - hoje.getTime()) / (1000 * 60 * 60 * 24),
      );

      // ==================================================
      // AVISO 3 DIAS ANTES - ASSINATURA ATIVA
      // ==================================================
      if (
        assinatura.status === "ativa" &&
        diffDias <= 3 &&
        diffDias >= 0 &&
        !assinatura.notificacaoRenovacaoEnviada
      ) {
        await db.collection("notificacoes").add({
          userId: assinatura.userId,

          tipo: "renovacao_assinatura",

          destino: "assinaturas_cliente",

          referenciaId: doc.id,

          titulo: "Sua assinatura está vencendo",

          mensagem:
            "Faltam 3 dias para o vencimento do seu plano. " +
            "Realize um novo pagamento para continuar com acesso aos benefícios.",

          lida: false,

          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });

        await doc.ref.set(
          {
            notificacaoRenovacaoEnviada: true,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      // ==================================================
      // AVISO 3 DIAS ANTES - CANCELAMENTO DEFINITIVO
      // ==================================================
      if (
        assinatura.status === "cancelamento_agendado" &&
        diffDias <= 3 &&
        diffDias >= 0 &&
        !assinatura.notificacaoCancelamentoEnviada
      ) {
        await db.collection("notificacoes").add({
          userId: assinatura.userId,

          tipo: "cancelamento_definitivo",

          destino: "assinaturas_cliente",

          referenciaId: doc.id,

          titulo: "Seu plano será encerrado",

          mensagem:
            "Faltam 3 dias para o cancelamento definitivo do seu plano. " +
            "Reative sua assinatura para continuar com acesso aos benefícios.",

          lida: false,

          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });

        await doc.ref.set(
          {
            notificacaoCancelamentoEnviada: true,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      // ==================================================
      // CANCELAMENTO DEFINITIVO AUTOMÁTICO
      // ==================================================
      if (
        assinatura.status === "cancelamento_agendado" &&
        beneficioAte <= hojeTexto
      ) {
        await doc.ref.set(
          {
            status: "cancelada",
            pagamentoStatus: "encerrado",
            planoAtivoNoMomento: false,

            encerradoEm: admin.firestore.FieldValue.serverTimestamp(),

            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        if (assinatura.userId) {
          await db.collection("usuarios").doc(assinatura.userId).set(
            {
              assinaturaAtiva: false,
              assinaturaStatus: "cancelada",
              plano: "",

              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        await db.collection("notificacoes").add({
          userId: assinatura.userId,

          tipo: "assinatura_cancelada",

          destino: "assinaturas_cliente",

          referenciaId: doc.id,

          titulo: "Plano encerrado",

          mensagem:
            "Seu plano foi encerrado. Assine novamente para recuperar os benefícios.",

          lida: false,

          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (assinatura.status === "ativa" && beneficioAte <= hojeTexto) {
        await doc.ref.set(
          {
            status: "cancelada",
            pagamentoStatus: "vencido",
            planoAtivoNoMomento: false,
            encerradoEm: admin.firestore.FieldValue.serverTimestamp(),
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        if (assinatura.userId) {
          await db.collection("usuarios").doc(assinatura.userId).set(
            {
              assinaturaAtiva: false,
              assinaturaStatus: "cancelada",
              plano: "",
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        await db.collection("notificacoes").add({
          userId: assinatura.userId,
          tipo: "assinatura_vencida",
          destino: "assinaturas_cliente",
          referenciaId: doc.id,
          titulo: "Assinatura vencida",
          mensagem:
            "Sua assinatura venceu. Faça um novo pagamento para recuperar os benefícios.",
          lida: false,
          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    console.log("VERIFICAÇÃO PAGBANK FINALIZADA");
  },
);

exports.cancelarSolicitacaoPagBankCliente = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { assinaturaId } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!assinaturaId) {
    throw new HttpsError("invalid-argument", "Solicitação inválida.");
  }

  const db = admin.firestore();
  const ref = db.collection("assinaturas_planos").doc(assinaturaId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Solicitação não encontrada.");
  }

  const assinatura = snap.data();

  if (assinatura.userId !== userId) {
    throw new HttpsError(
      "permission-denied",
      "Você não tem permissão para cancelar esta solicitação.",
    );
  }

  if (assinatura.status !== "aguardando_confirmacao") {
    throw new HttpsError(
      "failed-precondition",
      "Somente solicitações pendentes podem ser canceladas.",
    );
  }

  await ref.set(
    {
      status: "checkout_expirado",
      pagamentoStatus: "checkout_expirado",
      planoAtivoNoMomento: false,
      canceladoEm: admin.firestore.FieldValue.serverTimestamp(),
      canceladoPor: "cliente",
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true };
});

exports.confirmarPagamentoPagBankCliente = onCall(async (request) => {
  const userId = request.auth?.uid;
  const { assinaturaId } = request.data || {};

  if (!userId) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado.");
  }

  if (!assinaturaId) {
    throw new HttpsError("invalid-argument", "Assinatura inválida.");
  }

  const db = admin.firestore();
  const ref = db.collection("assinaturas_planos").doc(assinaturaId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Assinatura não encontrada.");
  }

  const assinatura = snap.data();

  if (assinatura.userId !== userId) {
    throw new HttpsError(
      "permission-denied",
      "Você não tem permissão para confirmar esta assinatura.",
    );
  }

  if (assinatura.status !== "aguardando_confirmacao") {
    throw new HttpsError(
      "failed-precondition",
      "Esta solicitação não está aguardando pagamento.",
    );
  }

  await ref.set(
    {
      status: "aguardando_aprovacao_admin",
      pagamentoStatus: "pagamento_informado",
      pagamentoInformadoEm: admin.firestore.FieldValue.serverTimestamp(),
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection("notificacoes").add({
    userId: "admin",
    tipo: "assinatura_pendente",
    destino: "assinaturas_admin",
    referenciaId: assinaturaId,
    titulo: "Pagamento informado",
    mensagem: `${assinatura.cliente || "Cliente"} informou pagamento do plano ${assinatura.planoNome || ""}. Confira no PagBank antes de ativar.`,
    lida: false,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
