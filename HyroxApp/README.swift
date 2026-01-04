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
//   - `SkeletonTrackingView` : preview + intégration initiale
//   - Remains: synchronisation frame-by-frame, overlay précis en temps réel
//
// Milestone 5 — Intégration ML / TensorFlow Lite
// - Objectifs : si on veut utiliser TFLite (ex: MoveNet), ajouter abstraction MLService
// - Statut : À FAIRE
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
//     les liens YouTube) et `VideoPlayer` (pour URLs directes).
// - `VideoRecorder.swift` : implémentation de base (session, movie output, preview view),
//   permission handling et correction de la conformance à `ObservableObject`.
// - `SkeletonAnalyzer.swift` : analyse Vision pour CMSampleBuffer et pour AVAsset (parcours
//   des frames et collecte d'observations VNHumanBodyPoseObservation).
// - `CompareVideosView.swift` : améliorations récentes
//   - Boutons de sélection fonctionnels sur macOS (éviter recouvrement titre/navigation).
//   - Lecture synchronisée des deux vidéos et observation périodique du temps.
//   - Analyse asynchrone des deux assets et stockage des `TimedObservation`.
//   - Exporteur qui compose deux pistes de skeleton superposées dans une vidéo résultat
//     (AVAssetWriter + PixelBuffer adaptor, rendu frame-by-frame).
//   - Ajout de `CombinedSkeletonOverlayView` (aperçu combiné dans l'UI) et du type
//     `TimedPoints` pour sérialiser points normalisés + timestamps.
//   - Corrections autour de la création / verrouillage des CVPixelBuffer (ownership & defer).
//   - MacOS `VideoPicker` pour ouvrir NSOpenPanel et retourner une URL sélectionnée.
// - `Info.plist` : vérifications clefs `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
//   `NSPhotoLibraryAddUsageDescription` déjà présentes.
// - Build : plusieurs corrections ont été appliquées pour lever des erreurs de compilation
//   liées aux buffers et aux types manquants; projet compilable localement après ces fixes.
//
// ------------------------------------------------------
// Ce qui reste à faire (liste priorisée + estimations)
// ------------------------------------------------------
// Priorité Haute
// 1) Intégrer aperçu caméra & boutons Start/Stop dans `SkeletonTrackingView` (test réel).
//    - Estimation : 0.5–1 jour
//
// 2) Pipeline d'analyse post-recording + overlay précis (synchronisation frame-by-frame).
//    - Détails : stocker observations avec timestamps/frames et utiliser ces données
//      pour un overlay exact pendant la lecture.
//    - Estimation : 1.5–3 jours
//
// 3) Robustifier UX YouTube embed (erreurs / bouton visible).
//    - Estimation : 0.5 jour
//
// Priorité Moyenne
// 4) Dessin avancé du squelette (angles, mesures, feedback).
//    - Estimation : 2 jours
//
// 5) Sauvegarde & export des sessions (video + JSON keypoints).
//    - Estimation : 1 jour
//
// 6) Préparer abstraction ML `MLService` + TFLite (SPM).
//    - Estimation : 2–4 jours
//
// Priorité Basse / Long terme
// 7) Dashboard, historique, tests unitaires & CI, optimisations.
//
// ------------------------------------------------------
// Dépendances & permissions
// ------------------------------------------------------
// - iOS target recommandé : 16.0+
// - Info.plist : NSCameraUsageDescription, NSMicrophoneUsageDescription, NSPhotoLibraryAddUsageDescription
// - Si vous utilisez TensorFlow Lite : ajouter via Swift Package Manager.
//
// ------------------------------------------------------
// Notes techniques / points d'attention
// ------------------------------------------------------
// - Le rendu vidéo des skeletons est fait en CG (CGContext) puis converti en CVPixelBuffer
//   pour être injecté via AVAssetWriterInputPixelBufferAdaptor. Veiller à la correspondance
//   du pixel format et au verrouillage/déverrouillage des buffers (use `defer`).
// - `convertToTimedPoints` normalise les points en (0..1) et inverse l'axe Y pour correspondre
//   au dessin CoreGraphics / SwiftUI en mode attendu.
// - `CombinedSkeletonOverlayView` utilise un échantillonnage par rapport au `currentTime`
//   pour afficher la position la plus proche dans chaque piste (left/right).
// - Pour améliorer la qualité d'export, ajuster taille vidéo, fps et connections des joints.
//
// ------------------------------------------------------
// Prochaines actions que je peux prendre maintenant (choisis une)
// ------------------------------------------------------
// A) Intégrer l'aperçu caméra + boutons Start/Stop dans `SkeletonTrackingView`.
// B) Lancer l'analyse post-enregistrement et afficher un overlay basique (neck + hip).
// C) Ajouter tests unitaires pour `RenameViewModel` et exécuter la suite.
// D) Préparer l'ajout de TensorFlow Lite (SPM package + README d'installation).
//
// Fin du README — mise à jour effectuée le 2026-01-04
// ------------------------------------------------------
