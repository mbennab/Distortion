using Godot;
using System;

public partial class TimeAunoteDansHubCentral : Node2D
{
	private TimeAunote timeAunote;
	private Vector2 positionEntreePrincipale;
	public bool started = false;
	public bool stopped = true;
	private StaticBody2D limites, porteJaune, porteBleue, porteRouge, porteGauche, porteDroite;
	private Godot.Timer timerSortie;
	private int speed { get; set; } = 200; // How fast the player will move (pixels/sec).
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		Hide();
		// charge les markers
		positionEntreePrincipale = GetNode<Marker2D>("fondHubCentral/Markers2D/entreePrincipale").Position; 
		// charge les limites et portes du HUB Central pour traitement des déplacements hors zone
		limites = GetNode<StaticBody2D>("fondHubCentral/limitesDeplacament");
		porteJaune = GetNode<StaticBody2D>("fondHubCentral/portesVoyageTemps/porteJaune");
		porteBleue = GetNode<StaticBody2D>("fondHubCentral/portesVoyageTemps/porteBleue");
		porteRouge = GetNode<StaticBody2D>("fondHubCentral/portesVoyageTemps/porteRouge");
		porteGauche = GetNode<StaticBody2D>("fondHubCentral/portesVoyageSalles/porteGauche");
		porteDroite = GetNode<StaticBody2D>("fondHubCentral/portesVoyageSalles/porteDroite");
		//charge le timer
		timerSortie = GetNode<Godot.Timer>("timerSortie");
		// charge et initialise le module TimeAunote
		timeAunote = GetNode<TimeAunote>("TimeAunote");
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		deplacement((float)delta);
	}
		
	public void start(){
		Show();
		// charge et initialise le module TimeAunote
		timeAunote = GetNode<TimeAunote>("TimeAunote");
		timeAunote.apparition(positionEntreePrincipale);
		started = true;
		stopped = false;
	}	
	
	public void stop(){
		Hide();
		started = false;
		stopped = true;
	}
	
	private void OnTimerSortieTimeout(){
		GD.Print("stop");
		Hide();
		started = false;
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
		// animation timeAunote
		timeAunote.animation(velocity.Normalized());
		// le vecteur aura une norme de 1 (meme vitesse en diagonale que horizontal ou vertical)
		avance(velocity.Normalized() * speed * delta);
	}	
	
	private void avance(Vector2 mouvement){
		//deplacement du time-aunote
		var collision = timeAunote.MoveAndCollide(mouvement);
		//traite les collisions
		if(collision != null){
			var collisioneur = collision.GetCollider();
			// si limites de déplacement rien à faire
			if(collisioneur==limites){
				GD.Print("limites");
				return;
			}
			// si portes alors voyage dans le temps
			if(collisioneur==porteJaune){
				GD.Print("porteJaune");
				//timeAunoteCollision.Disabled = true;
				// Animation de sortie
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("fondHubCentral/porteJauneAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("TimeAunote/animationTimeAunote");
				// Position du milieu de la porte pour deplacer le timeAunote
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("fondHubCentral/porteJauneAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, timeAunote.Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				// lancement des 2 animations
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				// lance le timer
				timerSortie.Start();
				//timeAunoteCollision.Disabled = false;
				return;
			}
			if(collisioneur==porteBleue){
				GD.Print("porteBleue");
				//timeAunoteCollision.Disabled = true;
				// Animation de sortie
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("fondHubCentral/porteBleueAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("TimeAunote/animationTimeAunote");
				// Position du milieu de la porte pour deplacer le timeAunote
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("fondHubCentral/porteBleueAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, timeAunote.Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				// lancement des 2 animations
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				// lance le timer
				timerSortie.Start();
				//timeAunoteCollision.Disabled = false;
				return;
			}
			if(collisioneur==porteRouge){
				GD.Print("porteRouge");
				//timeAunoteCollision.Disabled = true;
				// Animation de sortie
				AnimationPlayer animationPorte = GetNode<AnimationPlayer>("fondHubCentral/porteRougeAnimee/AnimationPlayer");
				AnimationPlayer animationPlayer = GetNode<AnimationPlayer>("TimeAunote/animationTimeAunote");
				// Position du milieu de la porte pour deplacer le timeAunote
				Vector2 destinationAnimationTimeAunote = GetNode<Sprite2D>("fondHubCentral/porteRougeAnimee").Position;
				Animation animation = animationPlayer.GetAnimation("animationPlayer");
				int trackId = animation.FindTrack(".:position", 0);
				animation.TrackSetKeyValue(trackId, 0, timeAunote.Position);
				animation.TrackSetKeyValue(trackId, 1, destinationAnimationTimeAunote);
				// lancement des 2 animations
				animationPorte.Play("animationPorte");
				animationPlayer.Play("animationPlayer");
				// lance le timer
				timerSortie.Start();
				//timeAunoteCollision.Disabled = false;
				return;
			}
			// si côté alors voyage dans le HUB
			if(collisioneur==porteGauche){
				GD.Print("porteGauche");
				Marker2D retour = GetNode<Marker2D>("fondHubCentral/Markers2D/retourDroite");
				timeAunote.Position = retour.GlobalPosition;
				return;
			}
			if(collisioneur==porteDroite){
				GD.Print("porteDroite");
				Marker2D retour = GetNode<Marker2D>("fondHubCentral/Markers2D/retourGauche");
				timeAunote.Position = retour.GlobalPosition;
				return;
			}
		}
	}

}
