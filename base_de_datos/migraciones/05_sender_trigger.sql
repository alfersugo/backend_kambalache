-- Trigger for mail queue notifications
CREATE OR REPLACE FUNCTION auth.notify_mail_queue()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('mail_queue', NEW.id::TEXT);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS mail_queue_notify ON auth.mail_queue;
CREATE TRIGGER mail_queue_notify
AFTER INSERT ON auth.mail_queue
FOR EACH ROW
EXECUTE FUNCTION auth.notify_mail_queue();