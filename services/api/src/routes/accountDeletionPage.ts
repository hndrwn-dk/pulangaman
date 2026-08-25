import { Router } from 'express';

export const accountDeletionPageRouter = Router();

accountDeletionPageRouter.get('/account-deletion', (_req, res) => {
  res.type('html').send(ACCOUNT_DELETION_HTML);
});

export const ACCOUNT_DELETION_HTML = `<!doctype html>
<html lang="id">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>PulangAman — Hapus Akun &amp; Data</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap"
      rel="stylesheet"
    />
    <style>
      :root {
        --bg: #faf7f0;
        --surface: #ffffff;
        --ink: #1c1917;
        --muted: #57534e;
        --accent: #2e6b4f;
        --accent-hover: #24563f;
        --danger: #a6432e;
        --danger-hover: #8a3726;
        --border: #e7e0d4;
        --focus: #2e6b4f;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: "Plus Jakarta Sans", system-ui, sans-serif;
        background: var(--bg);
        color: var(--ink);
        line-height: 1.5;
      }
      main {
        max-width: 32rem;
        margin: 0 auto;
        padding: 2rem 1.25rem 3.5rem;
      }
      h1 {
        font-size: 1.45rem;
        font-weight: 700;
        letter-spacing: -0.02em;
        margin: 0 0 0.6rem;
      }
      .lede {
        color: var(--muted);
        margin: 0 0 1.75rem;
        font-size: 0.95rem;
      }
      section {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: 1rem;
        padding: 1.25rem 1.2rem 1.4rem;
        margin-bottom: 1.1rem;
      }
      h2 {
        font-size: 1.05rem;
        font-weight: 700;
        margin: 0 0 0.7rem;
      }
      label {
        display: block;
        font-size: 0.8rem;
        font-weight: 600;
        margin: 0.85rem 0 0.35rem;
      }
      input {
        width: 100%;
        padding: 0.7rem 0.8rem;
        border: 1px solid var(--border);
        border-radius: 0.6rem;
        font: inherit;
        background: var(--bg);
      }
      input:focus {
        outline: 2px solid var(--focus);
        outline-offset: 1px;
      }
      button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        margin-top: 1rem;
        padding: 0.75rem 1rem;
        border: 0;
        border-radius: 999px;
        font: inherit;
        font-weight: 700;
        cursor: pointer;
        background: var(--accent);
        color: #fff;
      }
      button:hover:not(:disabled) { background: var(--accent-hover); }
      button.danger { background: var(--danger); }
      button.danger:hover:not(:disabled) { background: var(--danger-hover); }
      button:disabled { opacity: 0.55; cursor: not-allowed; }
      .msg { margin: 0.85rem 0 0; font-size: 0.9rem; }
      .msg.error { color: var(--danger); }
      .msg.ok { color: var(--accent); }
      .hidden { display: none; }
      #otp-step { margin-top: 0.25rem; }
      a { color: var(--accent); font-weight: 600; }
      .tier2 p { color: var(--muted); font-size: 0.92rem; margin: 0 0 0.85rem; }
      #recaptcha-container { min-height: 0; }
    </style>
    <script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-auth-compat.js"></script>
  </head>
  <body>
    <main>
      <header>
        <h1>PulangAman — Hapus Akun &amp; Data</h1>
        <p class="lede">
          Halaman ini menghapus akun PulangAman dan data terkait, sama seperti
          opsi hapus akun di dalam aplikasi. Verifikasi nomor HP terdaftar
          dengan kode OTP, lalu konfirmasi. Tindakan ini tidak bisa dibatalkan.
        </p>
      </header>

      <section>
        <h2>Hapus lewat nomor HP</h2>
        <label for="phone">Nomor HP (+62)</label>
        <input
          id="phone"
          type="tel"
          inputmode="tel"
          autocomplete="tel"
          placeholder="+62812..."
        />
        <button id="send-otp" type="button">Kirim kode OTP</button>

        <div id="otp-step" class="hidden">
          <label for="otp">Kode OTP</label>
          <input id="otp" type="text" inputmode="numeric" autocomplete="one-time-code" />
          <button id="confirm-delete" class="danger" type="button">
            Verifikasi &amp; Hapus Akun
          </button>
        </div>
        <p id="status" class="msg" role="status"></p>
        <div id="recaptcha-container"></div>
      </section>

      <section class="tier2">
        <h2>Tidak bisa menerima OTP?</h2>
        <p>
          Kirim email ke
          <a href="mailto:support@tursinalabs.com">support@tursinalabs.com</a>
          dengan nomor HP terdaftar dan nama anak (jika relevan) — permintaan
          diproses manual maks. 7 hari kerja.
        </p>
        <a
          href="mailto:support@tursinalabs.com?subject=Permintaan%20Hapus%20Akun%20PulangAman&amp;body=Nomor%20HP%20terdaftar%3A%0ANama%20anak%20(jika%20relevan)%3A%0AAlasan%20tidak%20bisa%20verifikasi%20otomatis%3A"
        >Kirim email permintaan hapus akun</a>
      </section>
    </main>
    <script>
      // TODO: replace with this project's Web app config from Firebase Console
      var firebaseConfig = {
        apiKey: "YOUR_API_KEY",
        authDomain: "YOUR_PROJECT.firebaseapp.com",
        projectId: "YOUR_PROJECT_ID",
        storageBucket: "YOUR_PROJECT.appspot.com",
        messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
        appId: "YOUR_APP_ID"
      };

      firebase.initializeApp(firebaseConfig);
      firebase.auth().languageCode = "id";

      var confirmationResult = null;
      var recaptchaVerifier = null;
      var statusEl = document.getElementById("status");
      var otpStep = document.getElementById("otp-step");
      var sendBtn = document.getElementById("send-otp");
      var confirmBtn = document.getElementById("confirm-delete");

      function setStatus(text, kind) {
        statusEl.textContent = text || "";
        statusEl.className = "msg" + (kind ? " " + kind : "");
      }

      function normalizePhoneE164(raw) {
        var trimmed = String(raw || "").trim().replace(/[\\s\\-]/g, "");
        if (trimmed.charAt(0) === "+") {
          return "+" + trimmed.slice(1).replace(/\\D/g, "");
        }
        var digits = trimmed.replace(/\\D/g, "");
        if (digits.charAt(0) === "0") return "+62" + digits.slice(1);
        if (digits.indexOf("62") === 0) return "+" + digits;
        return "+" + digits;
      }

      function firebaseMessage(err) {
        var code = err && err.code ? String(err.code) : "";
        if (code === "auth/invalid-phone-number") {
          return "Nomor telepon tidak valid. Gunakan format +62...";
        }
        if (code === "auth/too-many-requests") {
          return "Terlalu banyak percobaan. Coba lagi nanti.";
        }
        if (code === "auth/invalid-verification-code") {
          return "Kode OTP tidak valid.";
        }
        if (code === "auth/code-expired") {
          return "Kode OTP kedaluwarsa. Kirim ulang kode.";
        }
        return (err && err.message) ? String(err.message) : "Terjadi kesalahan. Coba lagi.";
      }

      sendBtn.addEventListener("click", function () {
        var phone = normalizePhoneE164(document.getElementById("phone").value);
        if (phone.length < 10) {
          setStatus("Masukkan nomor HP dengan format +62.", "error");
          return;
        }
        sendBtn.disabled = true;
        setStatus("Mengirim kode OTP...");
        if (recaptchaVerifier) {
          try { recaptchaVerifier.clear(); } catch (_) {}
          recaptchaVerifier = null;
        }
        recaptchaVerifier = new firebase.auth.RecaptchaVerifier("recaptcha-container", {
          size: "invisible"
        });
        firebase.auth().signInWithPhoneNumber(phone, recaptchaVerifier)
          .then(function (result) {
            confirmationResult = result;
            otpStep.classList.remove("hidden");
            setStatus("Kode OTP terkirim. Masukkan kode, lalu konfirmasi penghapusan.");
          })
          .catch(function (err) {
            setStatus(firebaseMessage(err), "error");
            if (recaptchaVerifier) {
              try { recaptchaVerifier.clear(); } catch (_) {}
              recaptchaVerifier = null;
            }
          })
          .then(function () {
            sendBtn.disabled = false;
          });
      });

      confirmBtn.addEventListener("click", function () {
        var otp = String(document.getElementById("otp").value || "").trim();
        if (!confirmationResult) {
          setStatus("Kirim kode OTP terlebih dahulu.", "error");
          return;
        }
        if (!otp) {
          setStatus("Masukkan kode OTP.", "error");
          return;
        }
        confirmBtn.disabled = true;
        sendBtn.disabled = true;
        setStatus("Memverifikasi dan menghapus akun...");
        confirmationResult.confirm(otp)
          .then(function (result) {
            return result.user.getIdToken();
          })
          .then(function (idToken) {
            return fetch("/api/v1/account", {
              method: "DELETE",
              headers: { Authorization: "Bearer " + idToken }
            }).then(function (res) {
              return res.text().then(function (text) {
                var body = null;
                if (text) {
                  try { body = JSON.parse(text); } catch (_) { body = { error: text }; }
                }
                return { res: res, body: body };
              });
            });
          })
          .then(function (outcome) {
            if (outcome.res.status === 204 || outcome.res.ok) {
              return firebase.auth().signOut().catch(function () {}).then(function () {
                setStatus("Akun dan data Anda telah dihapus.", "ok");
                otpStep.classList.add("hidden");
              });
            }
            var errCode = outcome.body && outcome.body.error;
            if (outcome.res.status === 403 && errCode === "child_deletion_requires_parent") {
              setStatus(
                "Akun anak dikelola oleh orang tua. Halaman ini tidak dapat menghapus akun anak secara langsung. Minta orang tua menghapus akun mereka, atau hapus data anak dari dalam aplikasi.",
                "error"
              );
              return;
            }
            setStatus(
              "Gagal menghapus akun" + (errCode ? " (" + errCode + ")." : "."),
              "error"
            );
          })
          .catch(function (err) {
            setStatus(firebaseMessage(err), "error");
          })
          .then(function () {
            confirmBtn.disabled = false;
            sendBtn.disabled = false;
          });
      });
    </script>
  </body>
</html>
`;
