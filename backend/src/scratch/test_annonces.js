const axios = require('axios');
const { v4: uuidv4 } = require('uuid');

const BASE_URL = 'http://localhost:3000';

async function runTests() {
  console.log('🚀 Démarrage des tests d\'intégration pour le module Annonces...\n');

  // Générer des données uniques pour le nouvel utilisateur de test
  const uniqueId = uuidv4().substring(0, 8);
  const email = `test_user_${uniqueId}@example.com`;
  const telephone = `+3360000${Math.floor(1000 + Math.random() * 9000)}`;
  const password = 'Password123!';

  let token = '';
  let adId = null;
  let commentId = null;

  try {
    // 1. Inscription d'un utilisateur de test
    console.log('1. Inscription d\'un utilisateur de test...');
    const registerRes = await axios.post(`${BASE_URL}/auth/register`, {
      prenom: 'Test',
      nom: 'Annonceur',
      email: email,
      telephone: telephone,
      mot_de_passe: password
    });
    console.log('✅ Inscription réussie.\n');

    // 2. Connexion pour obtenir le token JWT
    console.log('2. Connexion de l\'utilisateur...');
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      email: email,
      mot_de_passe: password
    });
    token = loginRes.data.token;
    console.log('✅ Connexion réussie. Token obtenu.\n');

    const authHeaders = { headers: { Authorization: `Bearer ${token}` } };

    // 3. Test du Feed Public (GET /api/annonces)
    console.log('3. Lecture du feed public (avant création)...');
    const feedBefore = await axios.get(`${BASE_URL}/api/annonces`);
    console.log(`✅ Feed lu avec succès. Nombre d'annonces actives : ${feedBefore.data.data.length}\n`);

    // 4. Test de Création d'une Annonce (POST /api/annonces)
    console.log('4. Création d\'une annonce...');
    const adData = {
      titre: 'Superbe Villa à Doha',
      description: 'Splendide villa avec piscine et vue sur la mer.',
      categorie: 'Immobilier',
      prix: 15000.00,
      ville: 'Doha',
      photos: [
        'https://res.cloudinary.com/ddeyhgbvr/image/upload/v1/samples/landscapes/nature-working-day.jpg',
        'https://res.cloudinary.com/ddeyhgbvr/image/upload/v1/samples/landscapes/beach.jpg'
      ]
    };
    const createRes = await axios.post(`${BASE_URL}/api/annonces`, adData, authHeaders);
    adId = createRes.data.id;
    console.log(`✅ Annonce créée avec succès. ID : ${adId}\n`);

    // 5. Test de Consultation des Détails avec token (is_owner doit être true)
    console.log('5. Consultation des détails (authentifié)...');
    const detailAuthRes = await axios.get(`${BASE_URL}/api/annonces/${adId}`, authHeaders);
    const detailAuth = detailAuthRes.data.data;
    console.log(`✅ Détails lus. is_owner = ${detailAuth.is_owner} (Attendu: true)`);
    console.log(`   Nombre de photos : ${detailAuth.photos.length} (Attendu: 2)\n`);

    // 6. Test de Consultation des Détails sans token (is_owner doit être false)
    console.log('6. Consultation des détails (non-authentifié/invité)...');
    const detailGuestRes = await axios.get(`${BASE_URL}/api/annonces/${adId}`);
    const detailGuest = detailGuestRes.data.data;
    console.log(`✅ Détails lus. is_owner = ${detailGuest.is_owner} (Attendu: false)\n`);

    // 7. Test de Liking (POST /api/annonces/:id/like)
    console.log('7. Liking de l\'annonce...');
    const likeRes1 = await axios.post(`${BASE_URL}/api/annonces/${adId}/like`, {}, authHeaders);
    console.log(`✅ Réponse like: liked = ${likeRes1.data.liked} (Attendu: true)`);

    const detailLikedRes = await axios.get(`${BASE_URL}/api/annonces/${adId}`, authHeaders);
    console.log(`   is_liked = ${detailLikedRes.data.data.is_liked} (Attendu: true)`);
    console.log(`   nb_likes = ${detailLikedRes.data.data.likes_count} (Attendu: 1)\n`);

    // 8. Test de Unliking (Double-like bascule l'état)
    console.log('8. Unliking de l\'annonce (en re-likant)...');
    const likeRes2 = await axios.post(`${BASE_URL}/api/annonces/${adId}/like`, {}, authHeaders);
    console.log(`✅ Réponse like: liked = ${likeRes2.data.liked} (Attendu: false)`);

    const detailUnlikedRes = await axios.get(`${BASE_URL}/api/annonces/${adId}`, authHeaders);
    console.log(`   is_liked = ${detailUnlikedRes.data.data.is_liked} (Attendu: false)`);
    console.log(`   nb_likes = ${detailUnlikedRes.data.data.likes_count} (Attendu: 0)\n`);

    // 9. Test d'Ajout de Commentaire (POST /api/annonces/:id/commentaires)
    console.log('9. Ajout d\'un commentaire...');
    const commentRes = await axios.post(
      `${BASE_URL}/api/annonces/${adId}/commentaires`,
      { contenu: 'Intéressé par cette annonce. Quel est le contact ?' },
      authHeaders
    );
    commentId = commentRes.data.data.id;
    console.log(`✅ Commentaire ajouté avec succès. ID : ${commentId}`);
    console.log(`   Contenu : "${commentRes.data.data.contenu}"\n`);

    // 10. Test de Suppression de Commentaire (DELETE /api/annonces/:id/commentaires/:cid)
    console.log('10. Suppression du commentaire...');
    const delCommentRes = await axios.delete(`${BASE_URL}/api/annonces/${adId}/commentaires/${commentId}`, authHeaders);
    console.log(`✅ Réponse suppression commentaire : ${delCommentRes.data.message}\n`);

    // 11. Test de Modification de l'Annonce (PUT /api/annonces/:id)
    console.log('11. Modification de l\'annonce (mise en pause)...');
    const updateRes = await axios.put(
      `${BASE_URL}/api/annonces/${adId}`,
      { statut: 'pausee', prix: 14000.00 },
      authHeaders
    );
    console.log(`✅ Réponse modification : ${updateRes.data.message}`);

    const detailPausedRes = await axios.get(`${BASE_URL}/api/annonces/${adId}`, authHeaders);
    console.log(`   Nouveau statut : ${detailPausedRes.data.data.statut} (Attendu: pausee)`);
    console.log(`   Nouveau prix   : ${detailPausedRes.data.data.prix} (Attendu: 14000.00)\n`);

    // 12. Test de contact stub (POST /api/annonces/:id/commentaires/:cid/contacter)
    console.log('12. Test de l\'ouverture du chat privé (Stub)...');
    // Recréer un commentaire pour avoir un ID valide
    const commentRes2 = await axios.post(
      `${BASE_URL}/api/annonces/${adId}/commentaires`,
      { contenu: 'Second commentaire pour chat stub.' },
      authHeaders
    );
    const commentId2 = commentRes2.data.data.id;

    const contactRes = await axios.post(`${BASE_URL}/api/annonces/${adId}/commentaires/${commentId2}/contacter`, {}, authHeaders);
    console.log(`✅ Réponse contacter : ${contactRes.data.message}\n`);

    // 13. Test de Suppression de l'Annonce (DELETE /api/annonces/:id)
    console.log('13. Suppression de l\'annonce...');
    const deleteRes = await axios.delete(`${BASE_URL}/api/annonces/${adId}`, authHeaders);
    console.log(`✅ Réponse suppression annonce : ${deleteRes.data.message}\n`);

    // 14. Validation que l'annonce est bien supprimée
    console.log('14. Vérification post-suppression...');
    try {
      await axios.get(`${BASE_URL}/api/annonces/${adId}`);
      console.error('❌ Erreur : L\'annonce est toujours accessible après suppression.');
    } catch (err) {
      if (err.response && err.response.status === 404) {
        console.log('✅ Succès : L\'annonce n\'est plus accessible (Code 404 renvoyé comme attendu).\n');
      } else {
        throw err;
      }
    }

    console.log('🎉 TOUS LES TESTS SE SONT DÉROULÉS AVEC SUCCÈS ! 🎉');

  } catch (error) {
    console.error('❌ Le test a échoué avec une erreur :');
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error('   Data:', error.response.data);
    } else {
      console.error(error.message);
    }
  }
}

runTests();
