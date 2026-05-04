using Godot;
using System;

public partial class TimeOnautePrehistoire : CharacterBody2D{
	
	private AnimatedSprite2D timeAunoteAnimation;  // animation du time-aunote
	private CollisionShape2D timeAunoteCollision;  // collisions du personnage
	private Timer timerAttente;
	private int speed { get; set; } = 200; // How fast the player will move (pixels/sec).
	private Vector2 ScreenSize; // Size of the game window.
	private AnimatedSprite2D animatedSprite2D;// = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
		
	public void setScreenSize(Vector2 sc)
	{
		ScreenSize = sc;
	}
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		ScreenSize = GetViewportRect().Size;
		// charge et initialise le module animation
		Hide();
		timeAunoteAnimation = GetNode<AnimatedSprite2D>("animation");
		timeAunoteAnimation.FlipH = false;
		timeAunoteAnimation.FlipV = false;
		timeAunoteAnimation.Play();
		// charge et initialise le module collision
		timeAunoteCollision = GetNode<CollisionShape2D>("collision");
		timeAunoteCollision.Disabled = true;
		// charge les limites et portes du monde pour traitement des déplacements hors zone
		// A FAIRE
		// charge le timer d'animation d'attente
		timerAttente = GetNode<Godot.Timer>("timerAttente");
		timerAttente.Start();
		
		// affiche le timeAunote
		/*Vector2 startPosition = new Vector2(
			x: 100,
			y: 100
		);
		apparition(startPosition);*/
		
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		deplacement((float)delta);
	}
	
	// le timeAunote est positionne a sa place de depart et est affiche
	public void apparition(Vector2 position){
		// active l'animation REPOS du personnage principal
		timeAunoteAnimation.Animation = "repos";
		// le met en position
		Position = position;
		//charge l'animation de depart
		AnimationPlayer animationPorte = GetNode<AnimationPlayer>("../fondPrehistoire/porteJauneAnimee/AnimationPlayer");
		AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("animationTimeOnaute");
		// affiche le personnage
		Show();
		//active l'animation de depart
		animationPorte.Play("animationPorte");
		animationPlayer.Play("animationPlayer");
		// active les collisions avec les autres corps
		timeAunoteCollision.Disabled = false;
	}
	
	private void deplacement(float delta){
		// calcule la vitesse de deplacement en fonction des touches
		var velocity = Vector2.Zero;
		//verticalement 
		if (Input.IsActionPressed("ui_up"))
			velocity.Y -= 1;
		if (Input.IsActionPressed("ui_down"))
			velocity.Y += 1;
		//horizontalement
		if (Input.IsActionPressed("ui_right"))
			velocity.X += 1;
		if (Input.IsActionPressed("ui_left")){
			velocity.X -= 1;
		}
		// le vecteur aura une norme de 1 (meme vitesse en diagonale que horizontal ou vertical)
		avance(velocity.Normalized() * speed * delta);
	}
	
	private void avance(Vector2 mouvement){
		if (mouvement == Vector2.Zero){
			if (timerAttente.IsStopped()) {
				timeAunoteAnimation.Animation = "attente";
			} else {
				timeAunoteAnimation.Animation = "repos";
			}
			return;
		}
		// animation de deplacement (vertical a la priorite pour l'animation)
		if (mouvement.X != 0) {
			timeAunoteAnimation.Animation = "marche_droite";
			if (mouvement.X > 0)
				timeAunoteAnimation.FlipH = false;
			else
				timeAunoteAnimation.FlipH = true;
		}
		if (mouvement.Y != 0) {
			if (mouvement.Y > 0) {
				timeAunoteAnimation.Animation = "marche_bas";
			} else {
				timeAunoteAnimation.Animation = "marche_haut";
			}
		} 
		//deplacement du time-aunote
		var collision = MoveAndCollide(mouvement);
		//redemarre le timer pour l'animation d'attente
		timerAttente.Start();
		//traite les collisions
		if(collision != null){
			/*var collisioneur = collision.GetCollider();
			// si limites de déplacement rien à faire
			if(collisioneur==limites){
				//GD.Print("limites");
				return;
			}
			// si portes alors voyage dans le temps
			if(collisioneur==porteJaune){
				GD.Print("porteJaune");
				timeAunoteCollision.Disabled = true;
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("../fondHubCentral/porteJauneAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("animationTimeAunote");
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("../fondHubCentral/porteJauneAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				timeAunoteCollision.Disabled = false;
				return;
			}
			if(collisioneur==porteBleue){
				GD.Print("porteBleue");
				timeAunoteCollision.Disabled = true;
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("../fondHubCentral/porteBleueAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("animationTimeAunote");
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("../fondHubCentral/porteBleueAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				timeAunoteCollision.Disabled = false;
				return;
			}
			if(collisioneur==porteRouge){
				GD.Print("porteRouge");
				timeAunoteCollision.Disabled = true;
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("../fondHubCentral/porteRougeAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("animationTimeAunote");
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("../fondHubCentral/porteRougeAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				timeAunoteCollision.Disabled = false;
				return;
			}
			// si côté alors voyage dans le HUB
			if(collisioneur==porteGauche){
				//GD.Print("porteGauche");
				Marker2D retour = GetNode<Marker2D>("../fondHubCentral/Markers2D/retourDroite");
				Position = retour.GlobalPosition;
				return;
			}
			if(collisioneur==porteDroite){
				//GD.Print("porteDroite");
				Marker2D retour = GetNode<Marker2D>("../fondHubCentral/Markers2D/retourGauche");
				Position = retour.GlobalPosition;
				return;
			}*/
		}
	}
	
}
