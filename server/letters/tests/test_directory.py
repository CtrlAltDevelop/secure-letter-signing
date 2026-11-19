def test_directory_lists_active_colleagues_with_their_permissions(world, make_user, dev):
    gone = make_user("gone@corp.test", grants=("letter.sign",))
    gone.is_active = False
    gone.save(update_fields=["is_active"])

    resp = world.alice_d.call("get", "/letters/directory")

    assert resp.status_code == 200
    by_email = {u["email"]: u for u in resp.data}
    assert "gone@corp.test" not in by_email
    assert world.signers[0].email in by_email
    assert by_email[world.signers[0].email]["permissions"] == ["letter.sign", "user"]
    assert set(by_email[world.alice.email]) == {"id", "email", "full_name", "title", "status_text", "permissions"}


def test_directory_needs_a_login(api):
    assert api.call("get", "/letters/directory").status_code == 401
