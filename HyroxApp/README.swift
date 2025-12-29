// README — HyroxApp
//
// Ce fichier contient le plan de développement (milestones) et l'état actuel
// du projet HyroxApp (version MVP initiale).
//
// Important: Ce fichier est volontairement écrit en commentaire Swift pour
// rester dans le projet sans impacter la compilation. Pour une vraie README,
// envisager de créer un `README.md` à la racine du repository.
//
// ------------------------------------------------------
// Milestones (plan itératif pour HyroxApp)
// ------------------------------------------------------
// Milestone 1 — Structure de base & navigation
// - Objectifs :
//   - Mettre en place l'app SwiftUI avec un écran d'accueil proposant trois
//     sections : "How to train", "Rename label", "Skeleton tracking".
//   - Navigation entre les écrans.
// - Livrables : `HomeView`, `HowToTrainView`, `RenameLabelView`,
//   `SkeletonTrackingView`, `RenameViewModel`.
// - Statut : TERMINÉ (fichiers ajoutés et navigation configurée).
// - Temps estimé : 1 jour
//
// Milestone 2 — Écran de renommage fonctionnel
// - Objectifs :
//   - Implémenter la logique de renommage et persistance (prototype via
//     UserDefaults).
// - Livrables : `RenameViewModel` (sauvegarde/chargement).
// - Statut : TERMINÉ (sauvegarde via UserDefaults opérationnelle).
// - Temps estimé : 0.5 jour
//
// Milestone 3 — Préparation ML (abstraction + tests hors caméra)
// - Objectifs :
//   - Créer une couche d'abstraction pour l'inférence ML (préparer
//     `MLService` et `TFLiteInterpreter`).
//   - Tester le chargement d'un modèle `.tflite` sur image statique.
// - Livrables : Fichiers ML à ajouter, dossier `Resources/Models`.
// - Statut : À FAIRE
// - Temps estimé : 2 jours
//
// Milestone 4 — Capture vidéo & pipeline preprocessing
// - Objectifs :
//   - Mettre en place `CameraService` (AVCapture) et récupérer des frames
//     pour le traitement.
// - Livrables : `CameraView`, `CameraService`, `ImagePreprocessor`.
// - Statut : À FAIRE
// - Temps estimé : 3 jours
//
// Milestone 5 — Overlay du squelette & affichage parallèle vidéo coach
// - Objectifs :
//   - Dessiner le squelette par-dessus la vidéo utilisateur et afficher la
//     vidéo du coach en parallèle.
// - Livrables : `SkeletonOverlayView`, `CoachVideoPlayerView`,
//   `SkeletonViewModel`.
// - Statut : À FAIRE
// - Temps estimé : 3 jours
//
// Milestone 6 — Enregistrement vidéo & synchronisation
// - Objectifs :
//   - Enregistrer la vidéo utilisateur et sauvegarder les keypoints avec
//     timestamps.
// - Livrables : `RecordingService`, format d'export (video + JSON).
// - Statut : À FAIRE
// - Temps estimé : 3 jours
//
// Milestone 7 — Optimisation & QA
// - Objectifs : Profiling, optimisation (Metal delegate / quantization),
//   tests sur device.
// - Statut : À FAIRE
// - Temps estimé : 3-5 jours
//
// ------------------------------------------------------
// Ce qui a déjà été implémenté (état actuel)
// ------------------------------------------------------
// 1) Navigation & UI initiale
//    - `ContentView.swift` modifié pour lancer `HomeView`.
//    - `HomeView.swift` ajouté : écran d'accueil avec boutons
//      "How to train", "Rename label", "Skeleton tracking".
//    - `HowToTrainView.swift` ajouté : vue placeholder listant
//      des exercices.
//    - `SkeletonTrackingView.swift` ajouté : placeholder pour
//      future intégration caméra + overlay.
//
// 2) Renommage
//    - `RenameLabelView.swift` ajouté : TextField + Save button.
//    - `ViewModels/RenameViewModel.swift` ajouté : logique de sauvegarde
//      via UserDefaults (key: `com.hyroxapp.label.currentName`).
//
// 3) Vérifications
//    - Les nouveaux fichiers ont été ajoutés et la vérification
//      statique locale n'a pas retourné d'erreurs.
//
// ------------------------------------------------------
// Checklist (acceptation) pour la première itération
// ------------------------------------------------------
// - [x] L'app compile sans erreurs (vérification statique effectuée).
// - [x] Écran d'accueil visible avec trois options.
// - [x] Navigation vers chaque vue placeholder.
// - [x] Écran de renommage sauvegarde et recharge la valeur (UserDefaults).
// - [ ] Tests unitaires pour `RenameViewModel` (à ajouter).
//
// ------------------------------------------------------
// Prochaines tâches recommandées (prioritaires)
// ------------------------------------------------------
// 1) Ajouter tests unitaires pour `RenameViewModel`.
// 2) Implémenter `CameraService` et afficher un aperçu caméra dans
//    `SkeletonTrackingView` (sans ML pour commencer).
// 3) Préparer l'abstraction ML (`MLService`) et ajouter TensorFlow Lite via
//    Swift Package Manager.
//
// ------------------------------------------------------
// Notes techniques & recommandations
// - Cible iOS recommandée : iOS 16+ (NavigationStack, Swift Concurrency).
// - Modèle ML recommandé : MoveNet (SinglePose Lightning) pour MVP.
// - Permission Info.plist : ajouter `NSCameraUsageDescription` et
//   `NSMicrophoneUsageDescription` avant d'activer l'enregistrement.
//
// Si tu veux, je peux maintenant :
// - ajouter les tests unitaires pour `RenameViewModel`, ou
// - implémenter un aperçu caméra basique dans `SkeletonTrackingView`.
// Indique quelle tâche tu préfères que je réalise ensuite.
