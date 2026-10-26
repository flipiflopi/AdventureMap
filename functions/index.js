const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ==========================================
// 🌍 TRADUCCIONES DE NOTIFICACIONES
// ==========================================

const translations = {
  es: {
    notifFavTitle: "❤️ Nuevo favorito",
    notifFavBody: (userName, spotName) => `${userName} agregó tu spot "${spotName}" a favoritos`,
    
    notifCommentTitle: "💬 Nuevo comentario",
    notifCommentBody: (userName, spotName, preview) => `${userName} comentó en tu spot "${spotName}": ${preview}`,
    
    notifSuggestionTitle: "✏️ Nueva sugerencia",
    notifSuggestionBody: (userName, spotName) => `${userName} sugirió cambios para tu spot "${spotName}"`,
    
    notifFriendRequestTitle: "👥 Nueva solicitud de amistad",
    notifFriendRequestBody: (userName) => `${userName} te envió una solicitud de amistad`,
    
    notifSpotApprovedTitle: "✅ Spot aprobado",
    notifSpotApprovedBody: (spotName) => `Tu spot "${spotName}" ha sido aprobado y ya está visible`,
    
    notifSuggestionApprovedTitle: "✅ Sugerencia aprobada",
    notifSuggestionApprovedBody: (spotName) => `Tu sugerencia para "${spotName}" ha sido aprobada`,
    
    notifSuggestionRejectedTitle: "❌ Sugerencia rechazada",
    notifSuggestionRejectedBody: (spotName) => `Tu sugerencia para "${spotName}" ha sido rechazada`,
  },
  
  en: {
    notifFavTitle: "❤️ New favorite",
    notifFavBody: (userName, spotName) => `${userName} added your spot "${spotName}" to favorites`,
    
    notifCommentTitle: "💬 New comment",
    notifCommentBody: (userName, spotName, preview) => `${userName} commented on your spot "${spotName}": ${preview}`,
    
    notifSuggestionTitle: "✏️ New suggestion",
    notifSuggestionBody: (userName, spotName) => `${userName} suggested changes for your spot "${spotName}"`,
    
    notifFriendRequestTitle: "👥 New friend request",
    notifFriendRequestBody: (userName) => `${userName} sent you a friend request`,
    
    notifSpotApprovedTitle: "✅ Spot approved",
    notifSpotApprovedBody: (spotName) => `Your spot "${spotName}" has been approved and is now visible`,
    
    notifSuggestionApprovedTitle: "✅ Suggestion approved",
    notifSuggestionApprovedBody: (spotName) => `Your suggestion for "${spotName}" has been approved`,
    
    notifSuggestionRejectedTitle: "❌ Suggestion rejected",
    notifSuggestionRejectedBody: (spotName) => `Your suggestion for "${spotName}" has been rejected`,
  }
};

function getTranslations(locale) {
  const lang = locale?.split('_')[0]?.split('-')[0] || 'es';
  return translations[lang] || translations.es;
}

// ==========================================
// 📨 ENVIAR NOTIFICACIÓN PUSH
// ==========================================

exports.onNotificationCreated = onDocumentCreated(
  "notifications/{docId}",
  async (event) => {
    const notification = event.data.data();
    if (!notification) {
      console.log("⚠️ Notificación sin datos");
      return;
    }

    try {
      const userId = notification.userId;
      console.log(`📨 Procesando notificación para: ${userId}`);
      
      const userDoc = await db.collection("users").doc(userId).get();
      
      if (!userDoc.exists) {
        console.log(`❌ Usuario no existe: ${userId}`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      const userLanguage = userData.language || 'es';

      if (!fcmToken) {
        console.log(`⚠️ Usuario sin FCM token: ${userId}`);
        return;
      }

      console.log(`🌍 Idioma del usuario: ${userLanguage}`);
      const t = getTranslations(userLanguage);

      // ==========================================
      // 🎨 GENERAR TÍTULO Y CUERPO SEGÚN IDIOMA DEL DESTINATARIO
      // ==========================================
      
      let title = notification.title || "AdventureMap";
      let body = notification.body || "";

      const type = notification.type;
      const actionUserName = notification.actionUserName || "Un usuario";
      const spotName = notification.spotName || "un spot";

      // 🌍 REGENERAR textos en el idioma correcto del destinatario
      switch (type) {
        case 'favoriteAdded':
          title = t.notifFavTitle;
          body = t.notifFavBody(actionUserName, spotName);
          break;

        case 'spotComment':
          const commentPreview = notification.commentPreview || "...";
          title = t.notifCommentTitle;
          body = t.notifCommentBody(actionUserName, spotName, commentPreview);
          break;

        case 'spotSuggestion':
          title = t.notifSuggestionTitle;
          body = t.notifSuggestionBody(actionUserName, spotName);
          break;

        case 'friendRequest':
          title = t.notifFriendRequestTitle;
          body = t.notifFriendRequestBody(actionUserName);
          break;

        case 'spotApproved':
          title = t.notifSpotApprovedTitle;
          body = t.notifSpotApprovedBody(spotName);
          break;

        case 'suggestionReviewed':
          const isApproved = notification.isApproved || false;
          if (isApproved) {
            title = t.notifSuggestionApprovedTitle;
            body = t.notifSuggestionApprovedBody(spotName);
          } else {
            title = t.notifSuggestionRejectedTitle;
            body = t.notifSuggestionRejectedBody(spotName);
          }
          break;

        default:
          console.log(`⚠️ Tipo desconocido: ${type}`);
      }

      // ==========================================
      // 📤 ENVIAR MENSAJE FCM
      // ==========================================

      const message = {
        notification: { title, body },
        data: {
          type: String(notification.type || ""),
          spotId: String(notification.spotId || ""),
          suggestionId: String(notification.suggestionId || ""),
          actionUserId: String(notification.actionUserId || ""),
          notificationId: String(event.params.docId),
        },
        token: fcmToken,
        android: {
          priority: "high",
          notification: {
            channelId: "adventuremap_channel",
            sound: "default",
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            }
          }
        }
      };

      console.log(`📤 Enviando push a ${userId}`);
      console.log(`   Título: ${title}`);
      console.log(`   Cuerpo: ${body}`);

      const response = await getMessaging().send(message);
      console.log(`✅ Push enviada: ${response}`);

    } catch (error) {
      console.error("❌ Error enviando push:", error);
      
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        await db.collection("users").doc(notification.userId).update({
          fcmToken: null
        });
      }
    }
  }
);

// ==========================================
// 🧹 LIMPIEZA DE NOTIFICACIONES ANTIGUAS
// ==========================================

exports.cleanOldNotifications = onSchedule(
  "0 3 * * 0",
  async (event) => {
    const threshold = new Date();
    threshold.setDate(threshold.getDate() - 30);

    try {
      const oldNotifications = await db
        .collection("notifications")
        .where("createdAt", "<", threshold)
        .get();

      if (oldNotifications.empty) {
        console.log("ℹ️ No hay notificaciones antiguas");
        return null;
      }

      const batch = db.batch();
      oldNotifications.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      
      console.log(`✅ Eliminadas ${oldNotifications.size} notificaciones`);
      return null;
    } catch (error) {
      console.error("❌ Error en limpieza:", error);
      throw error;
    }
  }
);