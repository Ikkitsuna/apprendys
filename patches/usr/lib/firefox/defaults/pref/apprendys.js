// Apprendys - Préférences Firefox par défaut
// Ces valeurs s'appliquent aux nouveaux profils

// Dossier de téléchargement → DEVOIRS (via raccourci ~/Devoirs cree au demarrage)
pref("browser.download.dir", "/home/apprendys/Devoirs");
pref("browser.download.folderList", 2);
pref("browser.download.useDownloadDir", true);

// Page d'accueil
pref("browser.startup.homepage", "https://www.google.fr");
pref("browser.startup.page", 1);

// Pas de "what's new" au démarrage
pref("browser.startup.firstrunSkipsHomepage", true);
pref("trailhead.firstrun.didSeeAboutWelcome", true);
