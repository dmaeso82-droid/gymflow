const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
initializeApp();
setGlobalOptions({maxInstances: 10, region: "europe-west1"});

Object.assign(exports, require("./billing"));
Object.assign(exports, require("./users"));
Object.assign(exports, require("./gamification"));
