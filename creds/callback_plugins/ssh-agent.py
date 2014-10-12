from struct import unpack
from ansible.utils import warning
from ansible.callbacks import display
from paramiko import RSAKey, Agent, Message
import StringIO

class CallbackModule(object):

    SSH2_AGENTC_ADD_IDENTITY = 17
    KEY_COMMENT = 'Ansible private key'

    def playbook_on_play_start(self, *args, **kwargs):
        pem = self.play.vars.get('creds_ssh_private_key', None)
        if pem is None: return
        key = RSAKey.from_private_key(StringIO.StringIO(pem))

        hexdigest = unpack('16B', key.get_fingerprint())
        hexdigest = ':'.join(['%02x' % x for x in hexdigest])
        display('Loading SSH private key %s' % hexdigest)

        pub = '%s %s %s' % (key.get_name(), key.get_base64(), self.KEY_COMMENT)
        for x in self.play.tasks() + self.play.handlers():
            y = getattr(x, 'module_vars', None)
            if y: y['creds_ssh_public_key'] = pub

        ssh_agent = self.play.vars.get('creds_ssh_agent', True)
        if not ssh_agent: return

        msg = Message()
        msg.add_byte(chr(self.SSH2_AGENTC_ADD_IDENTITY))
        msg.add_string(key.get_name())
        msg.add_mpint(key.n)
        msg.add_mpint(key.e)
        msg.add_mpint(key.d)
        msg.add_mpint(0)
        msg.add_mpint(key.p)
        msg.add_mpint(key.q)
        msg.add_string(self.KEY_COMMENT)

        agent = Agent()
        if agent._conn:
            agent._send_message(msg)
        else:
            warning('Failed to connect to ssh-agent')
        agent.close()
