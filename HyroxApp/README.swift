// README — HyroxApp (Mise à jour)
//
// Ce fichier liste les milestones, l'état actuel et ce qui reste à faire
// pour le projet HyroxApp. Tout est en français et en commentaire Swift
// pour rester intégré au projet sans impacter la compilation.
//
// ------------------------------------------------------
// Milestones (plan itératif pour HyroxApp)
// ------------------------------------------------------
// Milestone 1 — Structure de base & navigation
// - Objectifs : écran d'accueil (How to train / Rename label / Skeleton tracking)
// - Statut : TERMINÉ
//
// Milestone 2 — How To Train (exercices + vidéos)
// - Objectifs : liste d'exercices, détail avec lecture vidéo
// - Statut : MAJORITAIREMENT TERMINÉ
//   - Lecture YouTube intégrée via `YouTubePlayerView` (WKWebView embed)
//   - `Exercise`, `ExerciseRow`, `ExerciseDetailView` existants
//   - Détection automatique des liens YouTube dans `ExerciseDetailView`
//
// Milestone 3 — Renommage
// - Objectifs : renommer une étiquette et persister
// - Statut : TERMINÉ (`RenameViewModel` + `RenameLabelView`)
//
// Milestone 4 — Enregistrement vidéo & Skeleton Tracking (MVP)
// - Objectifs : enregistrement caméra, analyser la vidéo, superposer skeleton
// - Statut : PARTIELLEMENT IMPLÉMENTÉ
//   - `VideoRecorder` : session AVCapture, preview layer, start/stop enregistrement
//   - `SkeletonAnalyzer` : wrapper Vision VNDetectHumanBodyPoseRequest pour frames et assets
//   - `SkeletonTrackingView` : placeholder + intégration initiale possible
//   - Remains: synchronisation frame-by-frame, overlay précis, UI de replay/analyse
//
// Milestone 5 — Intégration ML / TensorFlow Lite
// - Objectifs : si on veut utiliser TFLite (ex: MoveNet), ajouter abstraction MLService
// - Statut : À FAIRE (préparation recommandée)
//
// Milestone 6 — Statistiques & persistances avancées
// - Objectifs : stocker sessions, keypoints, métriques, visualisations
// - Statut : À FAIRE
//
// ------------------------------------------------------
// Ce qui a été ajouté / corrigé récemment (état concret)
// ------------------------------------------------------
// - `HomeView`, `HowToTrainView`, `RenameLabelView`, `SkeletonTrackingView` créés.
// - `Exercise` model + `ExerciseRow` + `ExerciseDetailView` présents; HowToTrain utilise
//   désormais `ScrollView` + `LazyVStack` pour scroller verticalement.
// - YouTube support :
//   - `YouTubeWebView` / `YouTubePlayerView` wrapper (WKWebView) qui extrait
//     l'ID YouTube et charge l'URL embed (youtube-nocookie.com).
//   - `ExerciseDetailView` bascule automatiquement entre `YouTubePlayerView` (pour
//     les liens YouTube) et `VideoPlayer` (pour URLs directes) — dans ton cas toutes
//     les vidéos sont YouTube -> on utilise l'embed.
//   - Fallback : détection d'erreur de chargement dans le WebView et alerte avec
//     bouton "Ouvrir dans YouTube" si l'embed échoue.
// - `VideoRecorder.swift` : implémentation de base (session, movie output, preview view),
//   permission handling et correction de la conformance à `ObservableObject`.
// - `SkeletonAnalyzer.swift` : analyse Vision pour CMSampleBuffer et pour AVAsset (parcours
//   des frames et collecte d'observations VNHumanBodyPoseObservation).
// - `Info.plist` corrigé : ajout de `CFBundleExecutable` et des clés `NSCameraUsageDescription`,
//   `NSMicrophoneUsageDescription`, `NSPhotoLibraryAddUsageDescription`.
// - `project.pbxproj` : corrections de cibles invalides (remplacement des valeurs non valides)
//   et harmonisation `IPHONEOS_DEPLOYMENT_TARGET` → 16.0.
// - Build : le projet compile localement après ces corrections (tests de build via xcodebuild).
//
// ------------------------------------------------------
// Ce qui reste à faire (liste priorisée + estimations)
// ------------------------------------------------------
// Priorité Haute (à faire en premier)
// 1) Intégrer l'aperçu caméra & bouton d'enregistrement fonctionnels dans
//    `SkeletonTrackingView` (Test sur appareil réel).
//    - Détails : injecter `CameraPreviewView(previewLayer:)`, appeler
//      `recorder.requestPermissions`, `startSession`, `startRecording/stopRecording`.
//    - Estimation : 0.5–1 jour
//
// 2) Pipeline d'analyse vidéo (post-recording) + overlay basique temps réel
//    - Détails :
//      a) Après `stopRecording` lancer `SkeletonAnalyzer.analyzeAsset(url:)`.
//      b) Stocker observations avec timestamps ou frame index.
//      c) Dessiner keypoints sur la vidéo/replay en synchronisant timeline.
//    - Estimation : 1.5–3 jours
//
// 3) Robustifier l'UX YouTube embed (gestion erreurs / bouton visible)
//    - Détails : ajouter un bouton visible "Ouvrir dans YouTube" sous le player,
//      et proposer automatiquement l'ouverture si le chargement échoue après Xs.
//    - Estimation : 0.5 jour
//
// Priorité Moyenne
// 4) Dessin avancé du squelette (connecter joints, montrer angles/mesures)
//    - Détails : choisir la liste des joints, tracer segments, calculer angles
//      (ex: genou, hanche) pour feedback technique.
//    - Estimation : 2 jours
//
// 5) Sauvegarde & export des sessions (video + JSON keypoints)
//    - Détails : exporter .mov + .json (positions normalisées + timestamps).
//    - Estimation : 1 jour
//
// 6) Préparer l'abstraction ML `MLService` et ajouter TensorFlow Lite (SPM)
//    - Détails : créer interface `MLService` (inputs: CMSampleBuffer / CVPixelBuffer,
//      outputs: keypoints) et préparer le pipeline (quantized model, delegate Metal
//      pour accélération si besoin).
//    - Estimation : 2–4 jours (selon modèle choisi / conversion)
//
// Priorité Basse / Long terme
// 7) Stats & Dashboard (rappels, historique, progression)
// 8) Tests unitaires & CI (unit pour RenameViewModel, UI tests pour flux principaux)
// 9) Optimisations & Profiling (Core ML / Metal delegate / quantization)
//
// ------------------------------------------------------
// Dépendances & permissions
// ------------------------------------------------------
// - iOS target recommandé : 16.0+
// - Info.plist : NSCameraUsageDescription, NSMicrophoneUsageDescription,
//   NSPhotoLibraryAddUsageDescription (déjà ajoutées)
// - Si vous utilisez TensorFlow Lite : ajouter via Swift Package Manager
//   (ou fournir un binaire intégrable). Pense à vérifier la licence du modèle.
//
// ------------------------------------------------------
// Prochaines actions que je peux prendre maintenant (choisis une)
// ------------------------------------------------------
// A) Intégrer l'aperçu caméra + boutons Start/Stop dans `SkeletonTrackingView`
//    (préparer un petit UI prêt à tester sur device). — Estimation : 0.5 jour
// B) Lancer l'analyse post-enregistrement et afficher un overlay basique (neck + hip).
//    — Estimation : 1 jour
// C) Ajouter tests unitaires pour `RenameViewModel` et exécuter la suite.
//    — Estimation : 0.5 jour
// D) Préparer l'ajout de TensorFlow Lite (SPM package + README d'installation).
//    — Estimation : 0.5 jour
//
// ------------------------------------------------------
// Notes finales & conseils
// ------------------------------------------------------
// - Teste l'enregistrement et l'analyse sur un appareil réel (le simulateur ne
//   fournit pas une vraie caméra pour l'enregistrement).
// - Pour analyser frame-by-frame et superposer correctement, sauvegarde
//   observations avec timestamps (ou index de frame) afin de synchroniser
//   lors du replay.
// - Si tu veux que j'implémente une des options A/B/C/D ci‑dessus, dis laquelle
//   et je l'ajoute directement dans le projet (fichiers + build + tests rapides).
//
// Fin du README — mise à jour effectuée le 2026-01-02
// ------------------------------------------------------
