const simple = require("./lib/simple.js");
const util = require("util");
const moment = require("moment-timezone");
const fs = require("fs");
const fetch = require("node-fetch");
const { exec } = require("child_process");
const {
  generateWAMessage,
  areJidsSameUser,
  getAggregateVotesInPollMessage,
  proto,
  jidNormalizedUser,
  makeWASocket,
  makeWALegacySocket,
  extractMessageContent,
  makeInMemoryStore,
  prepareWAMessageMedia,
  downloadContentFromMessage,
  getBinaryNodeChild,
  jidDecode,
  generateForwardMessageContent,
  generateWAMessageFromContent,
  WAMessageStubType,
  WA_DEFAULT_EPHEMERAL,
} = require("baileys");
const chalk = require("chalk");

const isNumber = (x) => typeof x === "number" && !isNaN(x);
const delay = (ms) =>
  isNumber(ms) && new Promise((resolve) => setTimeout(resolve, ms));

const COOLDOWN_FILE = './database/cooldown.json';
const COOLDOWN_DURATION = 1; 

if (!fs.existsSync('./database')) {
  fs.mkdirSync('./database', { recursive: true });
}

let cooldowns = {};
try {
  if (fs.existsSync(COOLDOWN_FILE)) {
    cooldowns = JSON.parse(fs.readFileSync(COOLDOWN_FILE, 'utf8'));
    
    const now = Date.now();
    for (const key in cooldowns) {
      if (cooldowns[key] < now) {
        delete cooldowns[key];
      }
    }
  }
} catch (err) {
  console.error('Error loading cooldown data:', err);
  cooldowns = {};
}

const saveCooldowns = () => {
  try {
    fs.writeFileSync(COOLDOWN_FILE, JSON.stringify(cooldowns, null, 2));
  } catch (err) {
    console.error('Error saving cooldown data:', err);
  }
};

// Initialize grouponly settings if not exist
if (!global.db.data.settings) global.db.data.settings = {};
if (global.db.data.settings.grouponly === undefined) global.db.data.settings.grouponly = false;

module.exports = {
  async handler(chatUpdate) {
    if (global.db.data == null) await loadDatabase();
    this.msgqueque = this.msgqueque || [];
    if (!chatUpdate) return;
    this.pushMessage(chatUpdate.messages).catch(console.error);
    let m = chatUpdate.messages[chatUpdate.messages.length - 1];
    if (!m) return;
    if (m.message?.viewOnceMessageV2)
      m.message = m.message.viewOnceMessageV2.message;
    if (m.message?.documentWithCaptionMessage)
      m.message = m.message.documentWithCaptionMessage.message;
    if (m.message?.viewOnceMessageV2Extension)
      m.message = m.message.viewOnceMessageV2Extension.message;
    if (!m) return;
    try {
      m = simple.smsg(this, m) || m;
      if (!m) return;
      m.exp = 0;
      m.limit = false;
      m.isBaileys = m.id.startsWith("3EBO") || m.id.startsWith("BAE5");
      try {
        require("./lib/database.js")(m);
      } catch (e) {
        console.error(e);
      }
      const isROwner = [
        conn.decodeJid(global.conn.user.id),
        ...global.owner.map((a) => a + "@s.whatsapp.net"),
      ].includes(m.sender);
      const isOwner = isROwner || m.fromMe;
      const isMods = global.db.data.users[m.sender].moderator;
      const isPrems = global.db.data.users[m.sender].premium;
      const isBans = global.db.data.users[m.sender].banned;
      const isWhitelist = global.db.data.chats[m.chat].whitelist;
      if (m.isGroup) {
        let member = await (
          await conn.groupMetadata(m.chat)
        ).participants.map((a) => a.id);
        
        db.data.chats[m.chat].member = member;
        db.data.chats[m.chat].chat += 1;
      }
      
      if (m.mtype === 'GROUP_CREATE') {
        await conn.reply(m.chat, `Invite Group
• 30 Day / Rp 7k
• Permanen  / Rp 10k

Jika berminat hubungi: @${global.owner[0]} untuk order`, m);
        await conn.groupLeave(m.chat);
      }
        
      if (
        m.messageStubType ===
        (WAMessageStubType.CALL_MISSED_VOICE ||
          WAMessageStubType.CALL_MISSED_VIDEO)
      ) {
        await conn.reply(
          m.chat,
          "*[ System Notif ]* You are call this bot, I will blockir You",
          null,
        );
        await conn.delay(1000);
        await conn.updateBlockStatus(m.chat, "block");
      }
    
      if (isROwner) {
        db.data.users[m.sender].premium = true;
        db.data.users[m.sender].premiumDate = "PERMANENT";
        db.data.users[m.sender].limit = "PERMANENT";
        db.data.users[m.sender].moderator = true;
      } else if (isPrems) {
        db.data.users[m.sender].limit = "PERMANENT";
      } else if (!isROwner && isBans) return;

      // Check for grouponly mode (Skip for owners and mods)
      if (global.db.data.settings.grouponly && !m.isGroup && !isOwner && !isMods && !isPrems) {
        await this.reply(
          m.chat,
          "*[ Informasi ]*\nMaaf kamu tidak bisa memakai bot di private chat, gunakan bot hanya di dalam grub saja",
          null
        );
        return;
      }

      if (opts["queque"] && m.text && !(isMods || isPrems)) {
        let queque = this.msgqueque,
          time = 1000 * 5;

        const previousID = queque[queque.length - 1];
        queque.push(m.id || m.key.id);
        setInterval(async function () {
          if (queque.indexOf(previousID) === -1) clearInterval(this);
          else await delay(time);
        }, time);
      }
      db.data.users[m.sender].online = new Date() * 1;
      db.data.users[m.sender].chat += 1;
      if (opts["autoread"]) await this.readMessages([m.key]);
      if (opts["nyimak"]) return;
      if (
        !m.fromMe &&
        !isOwner &&
        !isPrems &&
        !isMods &&
        !isWhitelist &&
        opts["self"]
      )
        return;
      if (opts["swonly"] && m.chat !== "status@broadcast") return;

      if (typeof m.text !== "string") m.text = "";
      if (m.Baileys) return;
      m.exp += Math.ceil(Math.random() * 350);

      let usedPrefix;
      let _user =
        global.db.data &&
        global.db.data.users &&
        global.db.data.users[m.sender];

      const groupMetadata =
        (m.isGroup ? (conn.chats[m.chat] || {}).metadata : {}) || {};
      
      const participants = (m.isGroup ? groupMetadata.participants : []) || [];
      const user =
        (m.isGroup
          ? participants.find((u) => conn.decodeJid(u.id) === m.sender)
          : {}) || {}; // User Data
      const bot =
        (m.isGroup
          ? participants.find((u) => conn.decodeJid(u.id) == this.user.jid)
          : {}) || {}; // Your Data
      const isRAdmin = (user && user.admin == "superadmin") || false;
      const isAdmin = isRAdmin || (user && user.admin == "admin") || false; // Is User Admin?
      const isBotAdmin = (bot && bot.admin) || false; // Are you Admin?
      
      if (Math.random() < 0.05) { 
        const now = Date.now();
        for (const key in cooldowns) {
          if (cooldowns[key] < now) {
            delete cooldowns[key];
          }
        }
        saveCooldowns();
      }
      
      for (let name in global.plugins) {
        let plugin = plugins[name];
        if (!plugin) continue;
        if (plugin.disabled) continue;
        if (typeof plugin.all === "function") {
          try {
            await plugin.all.call(this, m, chatUpdate);
          } catch (e) {
            console.error(e);
          }
        }
        const str2Regex = (str) => str.replace(/[|\\{}()[\]^$+*?.]/g, "\\$&");
        let _prefix = plugin.customPrefix
          ? plugin.customPrefix
          : conn.prefix
            ? conn.prefix
            : global.prefix;
        let match = (
          _prefix instanceof RegExp // RegExp Mode?
            ? [[_prefix.exec(m.text), _prefix]]
            : Array.isArray(_prefix) // Array?
              ? _prefix.map((p) => {
                  let re =
                    p instanceof RegExp // RegExp in Array?
                      ? p
                      : new RegExp(str2Regex(p));
                  return [re.exec(m.text), re];
                })
              : typeof _prefix === "string" // String?
                ? [
                    [
                      new RegExp(str2Regex(_prefix)).exec(m.text),
                      new RegExp(str2Regex(_prefix)),
                    ],
                  ]
                : [[[], new RegExp()]]
        ).find((p) => p[1]);
        if (typeof plugin.before === "function")
          if (
            await plugin.before.call(this, m, {
              match,
              conn: this,
              participants,
              groupMetadata,
              user,
              bot,
              isROwner,
              isOwner,
              isRAdmin,
              isAdmin,
              isBotAdmin,
              isPrems,
              isBans,
              chatUpdate,
            })
          )
            continue;
        if (typeof plugin !== "function") continue;
        if (opts && match && m) {
          let result =
            ((opts?.["multiprefix"] ?? true) && (match[0] || "")[0]) ||
            ((opts?.["noprefix"] ?? false) ? null : (match[0] || "")[0]);
          usedPrefix = result;
          let noPrefix;
          if (isOwner) {
            noPrefix = !result ? m.text : m.text.replace(result, "");
          } else {
            noPrefix = !result ? "" : m.text.replace(result, "").trim();
          }
          let [command, ...args] = noPrefix.trim().split` `.filter((v) => v);
          args = args || [];
          let _args = noPrefix.trim().split` `.slice(1);
          let text = _args.join` `;
          command = (command || "").toLowerCase();
          let fail = plugin.fail || global.dfail;

          const prefixCommand = !result
            ? plugin.customPrefix || plugin.command
            : plugin.command;
          let isAccept =
            (prefixCommand instanceof RegExp && prefixCommand.test(command)) ||
            (Array.isArray(prefixCommand) &&
              prefixCommand.some((cmd) =>
                cmd instanceof RegExp ? cmd.test(command) : cmd === command,
              )) ||
            (typeof prefixCommand === "string" && prefixCommand === command);
          m.prefix = !!result;
          usedPrefix = !result ? "" : result;
          if (!isAccept) continue;
          m.plugin = name;
          m.chatUpdate = chatUpdate;
          if (
            m.chat in global.db.data.chats ||
            m.sender in global.db.data.users
          ) {
            let chat = global.db.data.chats[m.chat];
            let user = global.db.data.users[m.sender];
            if (
              name != "owner-unbanchat.js" &&
              chat &&
              chat.isBanned &&
              !isOwner
            )
              return;
            if (
              name != "group-unmute.js" &&
              chat &&
              chat.mute &&
              !isAdmin &&
              !isOwner
            )
              return;
          }

          if (db.data.settings.blockcmd.includes(command)) {
            dfail("block", m, this);
            continue;
          }
          if (plugin.rowner && plugin.owner && !(isROwner || isOwner)) {
            fail("owner", m, this);
            continue;
          }
          if (plugin.rowner && !isROwner) {
            fail("rowner", m, this);
            continue;
          }
          if (plugin.restrict) {
            fail("restrict", m, this);
            continue;
          }
          if (plugin.owner && !isOwner) {
            fail("owner", m, this);
            continue;
          }
          if (plugin.mods && !isMods) {
            fail("mods", m, this);
            continue;
          }
          if (plugin.premium && !isPrems) {
            fail("premium", m, this);
            continue;
          }
          if (plugin.banned && !isBans) {
            fail("banned", m, this);
            continue;
          }
          if (plugin.group && !m.isGroup) {
            fail("group", m, this);
            continue;
          } else if (plugin.botAdmin && !isBotAdmin) {
            fail("botAdmin", m, this);
            continue;
          } else if (plugin.admin && !isAdmin) {
            fail("admin", m, this);
            continue;
          }
          if (plugin.private && m.isGroup) {
            fail("private", m, this);
            continue;
          }
          if (plugin.register == true && _user.registered == false) {
            fail("unreg", m, this);
            continue;
          }
          
          // Enhanced cooldown check with JSON file storage
          const cooldownKey = `${m.sender}:${command}`;
          const currentTime = Date.now();
          
          // Skip cooldown check for owners, premium users, and moderators
          if (!isOwner && !isPrems && !isMods) {
            const userCooldown = cooldowns[cooldownKey];
            
            if (userCooldown && currentTime < userCooldown) {
              const timeLeft = Math.ceil((userCooldown - currentTime) / 1000);
              await this.reply(
                m.chat,
                `*[ COOLDOWN ]* Silahkan tunggu ${timeLeft} detik sebelum menggunakan fitur ini lagi.`,
                m
              );
              continue;
            }
            
            cooldowns[cooldownKey] = currentTime + COOLDOWN_DURATION;
            
            if (Object.keys(cooldowns).length % 10 === 0) { 
              saveCooldowns();
            }
          }
          
          let cmd;
          m.command = command;
          m.isCommand = true;
          if (m.isCommand) {
            let now = Date.now()
            if (m.command in global.db.data.respon) {
              cmd = global.db.data.respon[m.command];
              if (!isNumber(cmd.total)) cmd.total = 1;
              if (!isNumber(cmd.success)) cmd.success = m.error != null ? 0 : 1;
              if (!isNumber(cmd.last)) cmd.last = now;
              if (!isNumber(cmd.lastSuccess))
                cmd.lastSuccess = m.error != null ? 0 : now;
            } else
              cmd = db.data.respon[m.command] = {
                total: 1,
                success: m.error != null ? 0 : 1,
                last: now,
                lastSuccess: m.error != null ? 0 : now,
              };
            cmd.total += 1;
            cmd.last = now;
            if (m.error == null) {
              cmd.success += 1;
              cmd.lastSuccess = now;
            }
          }
          let xp = "exp" in plugin ? parseInt(plugin.exp) : 17;
          if (xp > 9999999999999999999999) m.reply("Ngecit -_-");
          else m.exp += xp;
          if (!_user.limit > 100 && _user.limit < 1) {
            let limit = `*[ YOUR LIMIT HAS EXPIRED ]*\n> • _Limit anda telah habis silahkan tunggu 24 jam untuk mereset limit anda, upgrade ke premium untuk mendapatkan unlimited limit_`;
            conn.sendMessage(
              m.chat,
              {
                text: limit,
              },
              { quoted: m },
            );
            continue;
          }
          if (plugin.level > _user.level) {
            let level = `*[ THE LEVEL IS NOT ENOUGH ]*\n> • _Kamu Perlu level *[ ${plugin.level} ]*, untuk mengakses ini, silahkan main minigame atau RPG untuk meningkatkan level anda_`;
            conn.sendMessage(
              m.chat,
              {
                text: level,
              },
              { quoted: m },
            );
            continue;
          }
          let extra = {
            match,
            usedPrefix,
            noPrefix,
            _args,
            args,
            command,
            text,
            conn: this,
            participants,
            groupMetadata,
            user,
            bot,
            isROwner,
            isOwner,
            isRAdmin,
            isAdmin,
            isBotAdmin,
            isPrems,
            isBans,
            chatUpdate,
          };
          try {
            await plugin.call(this, m, extra);
            if (!isPrems) m.limit = m.limit || plugin.limit || true;
          } catch (e) {
            m.error = e;
            console.error("Error", e);
            if (e) {
              let text = util.format(e);
              conn.logger.error(text);
              if (text.match("rate-overlimit")) return;
              if (e.name) {
                for (let jid of global.owner) {
                  let data = (await conn.onWhatsApp(jid))[0] || {};
                  if (data.exists)
                    this.reply(
                      data.jid,
                      `*[ REPORT ERROR ]*
*• Name Plugins :* ${m.plugin}
*• From :* @${m.sender.split("@")[0]} *(wa.me/${m.sender.split("@")[0]})*
*• Jid Chat :* ${m.chat} 
*• Command  :* ${usedPrefix + command}

*• Error Log :*
\`\`\`${text}\`\`\`
`.trim(),
                      m,
                    );
                }
                m.reply("*[ system notice ]* Terjadi kesalahan pada bot !");
              }
              m.reply(e);
            }
          } finally {
            if (typeof plugin.after === "function") {
              try {
                await plugin.after.call(this, m, extra);
              } catch (e) {
                console.error(e);
              }
            }
          }
          break;
        }
      }
    } catch (e) {
      console.error(e);
    } finally {
      // Save cooldowns every few minutes to ensure data persistence
      if (Date.now() % 300000 < 1000) { // Roughly every 5 minutes
        saveCooldowns();
      }
      
      if (opts["queque"] && m.text) {
        const quequeIndex = this.msgqueque.indexOf(m.id || m.key.id);
        if (quequeIndex !== -1) this.msgqueque.splice(quequeIndex, 1);
      }
      let user,
        stats = global.db.data.stats;
      if (m) {
        if (m.sender && (user = global.db.data.users[m.sender])) {
          user.exp += m.exp;
          user.limit -= m.limit * 1;
        }
        let stat;
        if (m.plugin) {
          let now = +new Date();
          if (m.plugin in stats) {
            stat = stats[m.plugin];
            if (!isNumber(stat.total)) stat.total = 1;
            if (!isNumber(stat.success)) stat.success = m.error != null ? 0 : 1;
            if (!isNumber(stat.last)) stat.last = now;
            if (!isNumber(stat.lastSuccess))
              stat.lastSuccess = m.error != null ? 0 : now;
          } else
            stat = stats[m.plugin] = {
              total: 1,
              success: m.error != null ? 0 : 1,
              last: now,
              lastSuccess: m.error != null ? 0 : now,
            };
          stat.total += 1;
          stat.last = now;
          if (m.error == null) {
            stat.success += 1;
            stat.lastSuccess = now;
          }
        }
      }
      try {
        require("./lib/print.js")(m, this, chatUpdate);
      } catch (e) {
        console.log(m, m.quoted, e);
      }
      if (m.isCommand) return conn.sendPresenceUpdate("composing", m.chat)
      if (opts["autoread"])
        await this.chatRead(
          m.chat,
          m.isGroup ? m.sender : undefined,
          m.id || m.key.id,
        ).catch(() => {});
    }
  },
  async participantsUpdate({ id, participants, action }) {
    if (opts["self"]) return;       
    if (global.isInit) return;
    let chat = global.db.data.chats[id] || {};
    let text = "";
    switch (action) {
      case 'add':
      case 'remove':
      case 'leave':
      case 'invite':
      case 'invite_v4':
        if (chat.welcome) {
          let groupMetadata = await this.groupMetadata(id);
          for (let user of participants) {
            let text = (action === 'add' ? (chat.sWelcome || 'Welcome, @user!')
              .replace('@subject', await this.getName(id))
              .replace('@desc', groupMetadata?.desc || '') :
              (chat.sBye || 'Bye, @user!'))
              .replace('@user', '@' + user.split('@')[0]);

            await conn.sendMessage(id, { text, mentions: [user] });
          }
        }
        break;
      case "promote":
        text =
          chat.sPromote ||
          this.spromote ||
          conn.spromote ||
          "@user ```is now Admin```";
      case "demote":
        if (!text)
          text =
            chat.sDemote ||
            this.sdemote ||
            conn.sdemote ||
            "@user ```is no longer Admin```";
        text = text.replace("@user", "@" + participants[0].split("@")[0]);
        if (chat.detect) this.sendMessage(id, { text: text });
        break;
    }
  },
  async deleteUpdate(message) {
    try {
      const { fromMe, id, participant } = message;
      if (fromMe) return;
      let msg = await this.serializeM(await this.loadMessage(id));
      if (!msg || !msg.message) return;
      const mtype = await getContentType(msg.message);
      if (mtype === "conversation") {
        msg.message.extendedTextMessage = { text: msg.message[mtype] };
      }
      await this.reply(
        msg.key?.remoteJid || participant || msg.chat,
        `*[ System notice ]* delete message detected !`,
        m,
      );
      await this.copyNForward(
        msg.key?.remoteJid || participant || msg.chat,
        msg || null,
        false,
      ).catch((e) => console.log(e, msg));
    } catch (e) {
      console.error(e);
    }
  },
  async pollUpdate(message) {
    for (const { key, update } of message) {
      if (message.pollUpdates) {
        const pollCreation = this.loadMessage(key.id);
        if (pollCreation) {
          const pollMessage = await getAggregateVotesInPollMessage({
            message: pollCreation.message,
            pollUpdates: pollCreation.pollUpdates,
          });
          message.pollUpdates[0].vote = pollMessage;
          console.log(pollMessage);
        }
      }
    }
  },
};

global.dfail = async (type, m, conn) => {
  if (!type || !m) return;

  const textMessages = {
    owner: "Fitur ini hanya dapat digunakan oleh Owner.",
    mods: "Fitur ini hanya tersedia untuk Moderator bot.",
    group: "Fitur ini hanya bisa digunakan di dalam grup.",
    private: "Fitur ini hanya bisa digunakan di chat pribadi.",
    admin: "Fitur ini hanya bisa digunakan oleh Admin grup.",
    botAdmin: "Mohon jadikan bot sebagai Admin terlebih dahulu untuk menggunakan fitur ini.",
    unreg: "Silakan daftar terlebih dahulu dengan format: .daftar nama.umur",
    premium: "Fitur ini hanya dapat digunakan oleh pengguna premium.",
    grouponly: "Bot sedang dalam mode grouponly. Bot hanya dapat digunakan di dalam grup."
  };

  const text = textMessages[type] || "Akses ditolak.";

  try {
 /*   await m.reply(text); */
  } catch (err) {
    console.error("dfail error:", err);
  }
};

let file = require.resolve(__filename);
fs.watchFile(file, () => {
  fs.unwatchFile(file);
  console.log(chalk.redBright("Update 'handler.js'"));
  delete require.cache[file];
  require(file);
});